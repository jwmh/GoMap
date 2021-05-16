//  Converted to Swift 5.4 by Swiftify v5.4.27034 - https://swiftify.com/
//
//  PersistentWebCache.swift
//  Go Map!!
//
//  Created by Bryce on 5/3/20.
//  Copyright © 2020 Bryce. All rights reserved.
//

import Foundation

@objcMembers
class PersistentWebCache<T: AnyObject>: NSObject {
    private let _cacheDirectory: URL
    private let _memoryCache: NSCache<NSString, T>
	private var _pending: [ String: [(T?) -> Void] ] // track objects we're already downloading so we don't issue multiple requests
    
    class func encodeKey(forFilesystem string: String) -> String {
        var string = string
        let allowed = CharacterSet(charactersIn: "/").inverted
        string = string.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return string
    }
    
    func fileEnumerator(withAttributes attr: NSArray?) -> FileManager.DirectoryEnumerator {
        return FileManager.default.enumerator(
            at: _cacheDirectory,
            includingPropertiesForKeys: (attr as? [URLResourceKey]),
            options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants, .skipsHiddenFiles],
            errorHandler: nil)!
    }
    
    func allKeys() -> [String] {
        var a: [AnyHashable] = []
        for url in fileEnumerator(withAttributes: nil) {
            guard let url = url as? URL else {
                continue
            }
            let s = url.lastPathComponent // automatically removes escape encoding
            a.append(s)
        }
        return a as? [String] ?? []
    }

	convenience override init() {
		self.init(name: "", memorySize: 0)
	}

    init(name: String, memorySize: Int) {
		let name = PersistentWebCache.encodeKey(forFilesystem: name)
		let bundleName = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String
		_cacheDirectory = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(bundleName ?? "", isDirectory: true).appendingPathComponent(name, isDirectory: true)

        _memoryCache = NSCache<NSString,T>()
        _memoryCache.countLimit = 10000
        _memoryCache.totalCostLimit = memorySize

		_pending = [:]

		super.init()

		try! FileManager.default.createDirectory(at: _cacheDirectory, withIntermediateDirectories: true, attributes: nil)
	}
    
    func removeAllObjects() {
        for url in fileEnumerator(withAttributes: nil) {
            guard let url = url as? URL else {
                continue
            }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
            }
        }
        _memoryCache.removeAllObjects()
    }
    
    func removeObjectsAsyncOlderThan(_ expiration: Date) {
        DispatchQueue.global(qos: .default).async(execute: { [self] in
            for url in fileEnumerator(withAttributes: [URLResourceKey.contentModificationDateKey]) {
                guard let url = url as? NSURL else {
                    continue
                }
                var date: AnyObject? = nil
                do {
                    try url.getResourceValue(&date, forKey: URLResourceKey.contentModificationDateKey)
                    if (date as? Date)?.compare(expiration).rawValue ?? 0 < 0 {
                        do {
                            try FileManager.default.removeItem(at: url as URL)
                        } catch {}
                    }
                } catch {}
            }
        })
    }
    
    @objc func getDiskCacheSize(_ pSize: UnsafeMutablePointer<Int>, count pCount: UnsafeMutablePointer<Int>) {
        var count = 0
        var size = 0
        for url in fileEnumerator(withAttributes: [URLResourceKey.fileAllocatedSizeKey]) {
            guard let url = url as? NSURL else {
                continue
            }
            var len: AnyObject? = nil
            do {
                try url.getResourceValue(&len, forKey: URLResourceKey.fileAllocatedSizeKey)
            } catch {}
            count += 1
            size += (len as? NSNumber)?.intValue ?? 0
        }
        pSize.pointee = size
        pCount.pointee = count
    }
    
    func object(
        withKey cacheKey: String,
        fallbackURL urlFunction: @escaping () -> URL,
        objectForData: @escaping (_ data: Data) -> T?,
        completion: @escaping (_ object: T?) -> Void
    ) -> T? {
        DbgAssert(Thread.isMainThread)
		assert( _memoryCache.totalCostLimit != 0 )
		if let cachedObject = _memoryCache.object(forKey: cacheKey as NSString) {
			return cachedObject
        }
        
		if let plist = _pending[cacheKey] {
			// already being downloaded
			_pending[cacheKey] = plist + [completion]
			return nil
        }
		_pending[cacheKey] = [completion]

        let processData: ((_ data: Data?) -> Bool) = { data in
			let obj = data != nil ? objectForData( data! ) : nil
            DispatchQueue.main.async(execute: {
				if let obj = obj {
					self._memoryCache.setObject(obj,
												forKey: cacheKey as NSString,
												cost: data!.count)
				}
				for completion in self._pending[cacheKey] ?? [] {
					completion( obj )
                }
				self._pending.removeValue(forKey: cacheKey)
            })
            return obj != nil
        }
        
        DispatchQueue.global(qos: .default).async(execute: { [self] in
            // check disk cache
            let fileName = PersistentWebCache.encodeKey(forFilesystem: cacheKey)
            let filePath = _cacheDirectory.appendingPathComponent(fileName)
			if let data = try? Data(contentsOf: filePath) {
				_ = processData( data )
            } else {
                // fetch from server
                let url = urlFunction()
                let request = URLRequest(url: url)
                let task = URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
					let data = ((response as? HTTPURLResponse)?.statusCode ?? 404) < 300 ? data : nil
					if processData(data) {
						DispatchQueue.global(qos: .default).async(execute: {
							(data! as NSData).write(to: filePath, atomically: true)
						})
					}
                })
                task.resume()
            }
        })
        return nil
    }
}

func DbgAssert(_ x: Bool) {
    assert(x, "unspecified")
}