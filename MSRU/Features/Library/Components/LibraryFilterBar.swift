//
//  LibraryFilterBar.swift
//  MSRU
//

import SwiftUI

struct LibraryFilterBar: View {

    @Binding var viewMode: LibraryViewMode
    @Binding var sortField: LibrarySortField
    @Binding var sortAscending: Bool
    @Binding var searchQuery: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            // Wide layout (single row with centered search input)
            HStack(spacing: 12) {
                HStack {
                    // Balanced leading space
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                searchInput
                    .frame(width: 280)

                HStack(spacing: 12) {
                    sortMenu
                    viewModePicker
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Compact layout (adaptive two rows)
            VStack(spacing: 8) {
                searchInput
                    .frame(maxWidth: .infinity)

                HStack {
                    sortMenu
                    Spacer()
                    viewModePicker
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Subviews

    private var searchInput: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("筛选歌曲…", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.callout)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var sortMenu: some View {
        Menu {
            Section("排序方式") {
                ForEach(LibrarySortField.allCases) { field in
                    Button {
                        if sortField == field {
                            sortAscending.toggle()
                        } else {
                            sortField = field
                            sortAscending = field == .dateAdded ? false : true
                        }
                    } label: {
                        HStack {
                            Text(field.title)
                            if sortField == field {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("顺序") {
                Button {
                    sortAscending = true
                } label: {
                    HStack {
                        Text("升序")
                        if sortAscending {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    sortAscending = false
                } label: {
                    HStack {
                        Text("降序")
                        if !sortAscending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(sortField.title, systemImage: sortAscending ? "arrow.up" : "arrow.down")
                .font(.callout)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var viewModePicker: some View {
        Picker("视图", selection: $viewMode) {
            ForEach(LibraryViewMode.allCases) { mode in
                Image(systemName: mode.systemImage)
                    .tag(mode)
                    .help(mode.title)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 80)
    }
}

// MARK: - Preview

#Preview("Library Filter Bar · Default") {
    @Previewable @State var viewMode: LibraryViewMode = .table
    @Previewable @State var sortField: LibrarySortField = .dateAdded
    @Previewable @State var sortAscending = false
    @Previewable @State var query = ""

    LibraryFilterBar(
        viewMode: $viewMode,
        sortField: $sortField,
        sortAscending: $sortAscending,
        searchQuery: $query
    )
    .frame(width: 700)
}

#Preview("Library Filter Bar · Populated Query") {
    @Previewable @State var viewMode: LibraryViewMode = .grid
    @Previewable @State var sortField: LibrarySortField = .title
    @Previewable @State var sortAscending = true
    @Previewable @State var query = "Aurora"

    LibraryFilterBar(
        viewMode: $viewMode,
        sortField: $sortField,
        sortAscending: $sortAscending,
        searchQuery: $query
    )
    .frame(width: 700)
}

#Preview("Library Filter Bar · Compact") {
    @Previewable @State var viewMode: LibraryViewMode = .table
    @Previewable @State var sortField: LibrarySortField = .dateAdded
    @Previewable @State var sortAscending = false
    @Previewable @State var query = ""

    LibraryFilterBar(
        viewMode: $viewMode,
        sortField: $sortField,
        sortAscending: $sortAscending,
        searchQuery: $query
    )
    .frame(width: 360)
}
