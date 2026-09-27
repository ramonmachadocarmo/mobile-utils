import SwiftUI
import WidgetKit

/// Widget da tela inicial com as notas fixadas (e não ocultas). Tocar numa nota
/// abre o app via mobileutils://app/quick_notes?copy=<id>, que copia o conteúdo.
/// (Extensões de widget não conseguem escrever na área de transferência.)
struct WidgetNote: Decodable, Identifiable {
  let id: String
  let title: String
  let content: String
}

struct NotesEntry: TimelineEntry {
  let date: Date
  let notes: [WidgetNote]
}

struct NotesProvider: TimelineProvider {
  static let appGroup = "group.com.ramonmachadocarmo.mobile_utils"
  static let key = "quick_notes_widget"

  func placeholder(in context: Context) -> NotesEntry {
    NotesEntry(date: Date(), notes: [WidgetNote(id: "1", title: "Chave Pix", content: "email@exemplo.com")])
  }

  func getSnapshot(in context: Context, completion: @escaping (NotesEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : NotesEntry(date: Date(), notes: load()))
  }

  // O app chama WidgetCenter.reloadAllTimelines() quando as notas mudam.
  func getTimeline(in context: Context, completion: @escaping (Timeline<NotesEntry>) -> Void) {
    completion(Timeline(entries: [NotesEntry(date: Date(), notes: load())], policy: .never))
  }

  private func load() -> [WidgetNote] {
    guard
      let raw = UserDefaults(suiteName: Self.appGroup)?.string(forKey: Self.key),
      let data = raw.data(using: .utf8)
    else { return [] }
    return (try? JSONDecoder().decode([WidgetNote].self, from: data)) ?? []
  }
}

struct QuickNotesWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: NotesEntry

  private var maxNotes: Int { family == .systemLarge ? 7 : 3 }

  /// O tamanho pequeno só aceita um toque para o widget inteiro (widgetURL).
  private var isSmall: Bool { family == .systemSmall }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Link(destination: URL(string: "mobileutils://app/quick_notes")!) {
        Text("Notas rápidas").font(.subheadline.bold())
          .foregroundColor(Color(red: 0.99, green: 0.59, blue: 0.02))
      }
      if entry.notes.isEmpty {
        Spacer()
        Text("Fixe notas no app para elas aparecerem aqui")
          .font(.caption).foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .multilineTextAlignment(.center)
        Spacer()
      } else {
        ForEach(entry.notes.prefix(maxNotes)) { note in
          if isSmall {
            Text(note.title).font(.footnote.bold()).lineLimit(1)
          } else {
            Link(destination: URL(string: "mobileutils://app/quick_notes?copy=\(note.id)")!) {
              VStack(alignment: .leading, spacing: 1) {
                Text(note.title).font(.footnote.bold()).lineLimit(1)
                Text(note.content.replacingOccurrences(of: "\n", with: " "))
                  .font(.caption2).foregroundColor(.secondary).lineLimit(1)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 10).padding(.vertical, 5)
              .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
            }
          }
        }
        Spacer(minLength: 0)
      }
    }
    .widgetURL(isSmall ? URL(string: "mobileutils://app/quick_notes") : nil)
    .widgetBackground()
  }
}

private extension View {
  @ViewBuilder func widgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(.fill.tertiary, for: .widget)
    } else {
      padding()
    }
  }
}

@main
struct QuickNotesWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "QuickNotesWidget", provider: NotesProvider()) { entry in
      QuickNotesWidgetView(entry: entry)
    }
    .configurationDisplayName("Notas rápidas")
    .description("Notas fixadas para copiar com um toque.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
