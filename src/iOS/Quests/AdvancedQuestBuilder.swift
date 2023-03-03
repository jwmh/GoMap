//
//  AdvancedQuestBuilder.swift
//  Go Map!!
//
//  Created by Bryce Cogswell on 2/19/23.
//  Copyright © 2023 Bryce Cogswell. All rights reserved.
//

import SwiftUI

@available(iOS 15.0.0, *)
struct AdvancedQuestBuilder: View {
	@Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
	var onSave: ((QuestDefinitionWithFilters) -> Bool)?
	@State var quest: QuestDefinitionWithFilters

	init(quest: QuestDefinitionWithFilters) {
		_quest = State(initialValue: quest)
	}

	var body: some View {
		List {
			Section(content: {
				VStack {
					Text("Advanced Quest Builder")
						.font(.title2)
						.padding([.horizontal, .bottom])

					Text("""
					This page allows you to design quests with more specific \
					criteria than the regular Quest Builder page.
					""")
					.font(.body)

					Spacer()

					Text("""
					Create a row in the table for each key/value pair and whether matching objects should be included or excluded. \
					Leave the value empty to indicate the key is not present. Use key=* to match any value.
					""")
					.font(.body)
					.padding(.bottom)
				}
			})

			Section(
				header: HStack {
					Text("Filters")
				},
				footer: HStack {
					Button(action: addRule) {
						Label("", systemImage: "plus")
					}
					Spacer()
					Button(action: clearAll) {
						Label("Clear All", systemImage: "").labelStyle(TitleOnlyLabelStyle())
					}
				},
				content: {
					ForEach($quest.filters, id: \.id) { $filter in
						AdvancedQuestFilterRowView(data: $filter)
					}
					.onDelete { indexSet in
						quest.filters.remove(atOffsets: indexSet)
					}
					.onMove { indexSet, index in
						quest.filters.move(fromOffsets: indexSet, toOffset: index)
					}
					.listRowSeparator(.hidden)
				})

			Section(
				header: Text("Keys"),
				content: {
					Text("What tag key is modified by this quest?")
					ForEach(quest.tagKeys.indices, id: \.self) { index in
						HStack {
							Spacer()
							TextField("", text: $quest.tagKeys[index])
								.frame(width: 200, alignment: .center)
								.textFieldStyle(.roundedBorder)
								.autocapitalization(.none)
							let showPlus = index == quest.tagKeys.count - 1
							Button(action: addKey) {
								Label("", systemImage: "plus")
							}
							.opacity(showPlus ? 1 : 0)
							.disabled(!showPlus)
							Spacer()
						}
					}
					.onDelete { indexSet in
						quest.tagKeys.remove(atOffsets: indexSet)
					}
					.onMove { indexSet, index in
						quest.tagKeys.move(fromOffsets: indexSet, toOffset: index)
					}
					.listRowSeparator(.hidden)
				})

			Section(
				header: Text("Name"),
				content: {
					Text(
						"What is the name of this quest? This is best written in the form of an action like 'Add Surface':")
					TextField("", text: $quest.title)
						.textInputAutocapitalization(.words)
						.frame(alignment: .center)
						.textFieldStyle(.roundedBorder)
				})

			Section(
				header: Text("Icon"),
				content: {
					Text("Provide a single-character symbol to identify this quest:")
					TextField("", text: $quest.label)
						.frame(width: 60, alignment: .center)
						.textFieldStyle(.roundedBorder)
				})
		}
		.navigationBarBackButtonHidden()
		.navigationBarItems(
			leading: Button(action: {
				presentationMode.wrappedValue.dismiss()
			}) {
				Text("Cancel").font(.body)
			},
			trailing: Button(action: {
				// Do some cleanup before saving
				quest.filters = quest.filters.map({ item in
					QuestDefinitionFilter(
						tagKey: item.tagKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
						tagValue: item.tagValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
						relation: item.relation,
						included: item.included)
				})
				quest.title = quest.title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
				quest.label = quest.label.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
				quest.tagKeys = quest.tagKeys.compactMap {
					let s = $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
					return s.isEmpty ? nil : s
				}

				if let onSave = onSave,
				   onSave(quest)
				{
					presentationMode.wrappedValue.dismiss()
				}
			}) {
				Text("Save").font(.body).bold()
			})
	}

	func addRule() {
		quest.filters.append(QuestDefinitionFilter(tagKey: "", tagValue: "", relation: .equal, included: .include))
	}

	func clearAll() {
		quest.filters.removeAll()
		addRule()
	}

	func addKey() {
		quest.tagKeys.append("")
	}
}

@available(iOS 15.0.0, *)
struct AdvancedQuestBuilder_Previews: PreviewProvider {
	static let quest = QuestDefinitionWithFilters(title: "Add Cuisine",
	                                              label: "🍽️",
	                                              tagKeys: ["cuisine"],
	                                              filters: [
	                                              	QuestDefinitionFilter(
	                                              		tagKey: "amenity",
	                                              		tagValue: "restaurant",
	                                              		relation: .equal,
	                                              		included: .include),
	                                              	QuestDefinitionFilter(
	                                              		tagKey: "cuisine",
	                                              		tagValue: "",
	                                              		relation: .equal,
	                                              		included: .include)
	                                              ])

	static var previews: some View {
		AdvancedQuestBuilder(quest: quest)
	}
}
