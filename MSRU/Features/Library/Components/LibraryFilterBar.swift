//
//  LibraryFilterBar.swift
//  MSRU
//

import SwiftUI
import MusicLibrary

struct LibraryFilterBar: View {

    @Binding var viewMode: LibraryViewMode
    @Binding var sortField: LibrarySortField
    @Binding var sortAscending: Bool
    @Binding var searchQuery: String
    var isSearching: Bool = false
    var showsSearch: Bool = true
    var prompt: LocalizedStringKey = "Filter songs…"
    var onOpenCleanup: (() -> Void)? = nil

    var body: some View {
        if showsSearch {
            ViewThatFits(in: .horizontal) {
                // Wide layout (single row with centered search input)
                HStack(spacing: 12) {
                    HStack {
                        if let onOpenCleanup {
                            Button(action: onOpenCleanup) {
                                Label("Clean Up", systemImage: "wand.and.stars")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Find duplicates, incomplete info and missing artwork")
                        }
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
                        if let onOpenCleanup {
                            Button(action: onOpenCleanup) {
                                Label("Clean Up", systemImage: "wand.and.stars")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Find duplicates, incomplete info and missing artwork")
                        }
                        Spacer()
                        sortMenu
                        viewModePicker
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        } else {
            HStack(spacing: 12) {
                if let onOpenCleanup {
                    Button(action: onOpenCleanup) {
                        Label("Clean Up", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Find duplicates, incomplete info and missing artwork")
                }
                Spacer()
                sortMenu
                viewModePicker
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Subviews

    private var searchInput: some View {
        HStack(spacing: 6) {
            if isSearching {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            TextField(prompt, text: $searchQuery)
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
            Section("Sort By") {
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
                            Text(LocalizedStringKey(field.title))
                            if sortField == field {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("Order") {
                Button {
                    sortAscending = true
                } label: {
                    HStack {
                        Text("Ascending")
                        if sortAscending {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    sortAscending = false
                } label: {
                    HStack {
                        Text("Descending")
                        if !sortAscending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label(LocalizedStringKey(sortField.title), systemImage: sortAscending ? "arrow.up" : "arrow.down")
                .font(.callout)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var viewModePicker: some View {
        Picker("View", selection: $viewMode) {
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
