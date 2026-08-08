import Foundation
import SwiftData

/// Populates a fresh install with sample chats, emails, and archive PDFs, then runs the
/// "initialization stage" embedding scan: one embedding per chat thread, one per chat message,
/// one per email, and one per bundled archive document (from its first two pages' extracted
/// text). `SemanticSearchService.indexIfNeeded` makes the scan idempotent, so this is safe to
/// call on every launch, not just the first. Mirrors the Android sibling app's `DemoDataSeeder`,
/// including its sample content, for behavioral parity between the two apps.
@MainActor
final class DemoDataSeeder {
    private let modelContext: ModelContext
    private let searchService: SemanticSearchService
    private let textExtractor = PdfTextExtractor()

    init(modelContext: ModelContext, searchService: SemanticSearchService) {
        self.modelContext = modelContext
        self.searchService = searchService
    }

    func seedIfNeeded() async {
        if (try? modelContext.fetchCount(FetchDescriptor<ChatThread>())) == 0 {
            seedChats()
        }
        if (try? modelContext.fetchCount(FetchDescriptor<EmailItem>())) == 0 {
            seedEmails()
        }
        if (try? modelContext.fetchCount(FetchDescriptor<ArchiveDocument>())) == 0 {
            seedArchive()
        }
        try? modelContext.save()
        await indexEverything()
    }

    /// Per-thread search suggestion chips, tailored to that thread's actual seeded content —
    /// used by `ChatThreadView`'s local search bar.
    static func chatSearchSuggestions(forThreadId threadId: String) -> [String] {
        sampleChats.first(where: { $0.id == threadId })?.suggestions ?? []
    }

    private func seedChats() {
        for chat in Self.sampleChats {
            let preview = chat.messages.last?.text ?? ""
            modelContext.insert(ChatThread(
                id: chat.id, title: chat.title, emoji: chat.emoji,
                lastUpdatedMillis: chat.lastUpdatedMillis, lastMessagePreview: preview
            ))
            for (index, message) in chat.messages.enumerated() {
                modelContext.insert(ChatMessage(
                    id: "\(chat.id)_msg\(index)",
                    threadId: chat.id,
                    sender: message.sender,
                    text: message.text,
                    timestampMillis: chat.lastUpdatedMillis - Int64(chat.messages.count - index) * 60_000
                ))
            }
        }
    }

    private func seedEmails() {
        for email in Self.sampleEmails {
            modelContext.insert(email)
        }
    }

    private func seedArchive() {
        for doc in Self.sampleDocuments {
            let document = ArchiveDocument(
                id: doc.id, title: doc.title, fileName: doc.fileName,
                source: .bundled, pageCount: 1, importedAtMillis: 0
            )
            document.pageCount = textExtractor.pageCount(document)
            modelContext.insert(document)
        }
    }

    private func indexEverything() async {
        let threads = (try? modelContext.fetch(FetchDescriptor<ChatThread>())) ?? []
        for thread in threads {
            let threadId = thread.id
            let messages = (try? modelContext.fetch(FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.threadId == threadId }
            ))) ?? []
            let transcript = messages
                .sorted { $0.timestampMillis < $1.timestampMillis }
                .map { "\($0.sender == .me ? "Me" : "Them"): \($0.text)" }
                .joined(separator: "\n")
            await searchService.indexIfNeeded(
                id: thread.id, scope: .chatThread, parentId: nil,
                title: thread.title, snippet: messages.last?.text ?? "", textToEmbed: transcript
            )
            for message in messages {
                await searchService.indexIfNeeded(
                    id: message.id, scope: .chatMessage, parentId: thread.id,
                    title: thread.title, snippet: message.text, textToEmbed: message.text
                )
            }
        }

        let emails = (try? modelContext.fetch(FetchDescriptor<EmailItem>())) ?? []
        for email in emails {
            await searchService.indexIfNeeded(
                id: email.id, scope: .email, parentId: nil,
                title: email.subject,
                snippet: "From: \(email.from) — \(String(email.body.prefix(120)))",
                textToEmbed: "\(email.subject)\n\(email.body)"
            )
        }

        let documents = (try? modelContext.fetch(FetchDescriptor<ArchiveDocument>())) ?? []
        for document in documents {
            let text = textExtractor.extractFirstPages(document)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            await searchService.indexIfNeeded(
                id: document.id, scope: .archiveDocument, parentId: nil,
                title: document.title, snippet: String(text.prefix(160)), textToEmbed: text
            )
        }
    }

    // MARK: - Sample content

    private struct SeedMessage {
        let sender: MessageSender
        let text: String
    }

    private struct SeedChat {
        let id: String
        let title: String
        let emoji: String
        let lastUpdatedMillis: Int64
        let messages: [SeedMessage]
        /// Three reasonable local-search suggestions, grounded in what this thread actually says.
        let suggestions: [String]
    }

    private struct SeedDocument {
        let id: String
        let title: String
        let fileName: String
    }

    private static let now = Int64(Date().timeIntervalSince1970 * 1000)

    private static let sampleChats: [SeedChat] = [
        SeedChat(
            id: "chat_db_sync", title: "Database Optimization Sync", emoji: "💾",
            lastUpdatedMillis: now - 10 * 60_000,
            messages: [
                SeedMessage(sender: .other, text: "Query latency on the orders table is still spiking during peak hours."),
                SeedMessage(sender: .me, text: "Did the new composite index on (customer_id, created_at) go out?"),
                SeedMessage(sender: .other, text: "Yes, deployed this morning. p99 dropped from 800ms to 210ms."),
                SeedMessage(sender: .me, text: "Nice. Let's also cache the top-N query results for an hour."),
                SeedMessage(sender: .other, text: "Will keep you updated, starting the final dry run now."),
                SeedMessage(sender: .other, text: "Dry run looks solid — cache hit rate is already at 87% after 20 minutes."),
                SeedMessage(sender: .me, text: "That's great. What about the connection pool — are we still seeing timeouts under load?"),
                SeedMessage(sender: .other, text: "A few, but way down. I bumped max connections from 50 to 80 and added a 2s statement timeout."),
                SeedMessage(sender: .me, text: "Good call. Let's schedule a follow-up review after it's been in prod for a week."),
                SeedMessage(sender: .other, text: "Sounds good, I'll put together a metrics summary by Friday."),
            ],
            suggestions: ["composite index deployment", "cache hit rate results", "connection pool timeout fix"]
        ),
        SeedChat(
            id: "chat_travel_planner", title: "Tokyo & Kyoto Travel Planner", emoji: "✈️",
            lastUpdatedMillis: now - 3 * 60 * 60_000,
            messages: [
                SeedMessage(sender: .me, text: "What time is our flight departure on the 12th?"),
                SeedMessage(sender: .other, text: "9:40 AM out of SFO, connecting through Haneda."),
                SeedMessage(sender: .me, text: "We should catch the 10 AM shinkansen back to check into our Shibuya hotel."),
                SeedMessage(sender: .other, text: "Are we doing the Shibuya Sky observation deck?"),
                SeedMessage(sender: .me, text: "Yes, sunset tickets are booked for 5:30 PM."),
                SeedMessage(sender: .other, text: "Can't wait! Make sure your passport is packed."),
                SeedMessage(sender: .other, text: "Do we have the JR train pass sorted for the Kyoto leg?"),
                SeedMessage(sender: .me, text: "Yes, 7-day pass activates the day we land in Osaka."),
                SeedMessage(sender: .other, text: "Perfect. Let's also pencil in Fushimi Inari early morning before the crowds."),
                SeedMessage(sender: .me, text: "Good idea — 6:30 AM start, then breakfast near the shrine after."),
            ],
            suggestions: ["flight departure time", "JR train pass Kyoto", "Fushimi Inari morning plan"]
        ),
        SeedChat(
            id: "chat_cookie_recipes", title: "Baking Cookie Recipes", emoji: "🍪",
            lastUpdatedMillis: now - 5 * 60 * 60_000,
            messages: [
                SeedMessage(sender: .other, text: "Do you have the recipe details for the gluten-free chocolate chip cookies?"),
                SeedMessage(sender: .me, text: "Yes! Almond flour, brown butter, and a pinch of flaky salt on top."),
                SeedMessage(sender: .other, text: "How long do you chill the dough before baking?"),
                SeedMessage(sender: .me, text: "At least 24 hours — makes a huge difference in the texture."),
                SeedMessage(sender: .other, text: "Great, see you soon. I'll preheat the oven."),
                SeedMessage(sender: .other, text: "What temperature and how long in the oven?"),
                SeedMessage(sender: .me, text: "350°F for about 11 minutes, rotate the tray halfway through."),
                SeedMessage(sender: .other, text: "Got it. Do you use a scoop or roll them by hand?"),
                SeedMessage(sender: .me, text: "A 2-tablespoon scoop, keeps them consistent — and don't flatten them before baking."),
                SeedMessage(sender: .other, text: "Perfect, that's exactly what I needed. Starting the dough now."),
            ],
            suggestions: ["gluten-free cookie ingredients", "dough chilling time", "baking temperature and time"]
        ),
        SeedChat(
            id: "chat_hiit_fitness", title: "HIIT Fitness & Leg Day Routine", emoji: "🏋️",
            lastUpdatedMillis: now - 8 * 60 * 60_000,
            messages: [
                SeedMessage(sender: .me, text: "What's on the plan for leg day this week?"),
                SeedMessage(sender: .other, text: "Squats, Bulgarian split squats, then 20 minutes on the bike."),
                SeedMessage(sender: .me, text: "20 minutes on the bike followed by hip openers and goblet stretch. Are calves targeted separately?"),
                SeedMessage(sender: .other, text: "Yeah, standing calf raises at the end, three sets to failure."),
                SeedMessage(sender: .other, text: "How's your squat depth feeling after the mobility work last week?"),
                SeedMessage(sender: .me, text: "Way better, no more pinching at the bottom of the rep."),
                SeedMessage(sender: .other, text: "Great — let's add front squats to the rotation then."),
                SeedMessage(sender: .me, text: "Sounds good. What's the rep scheme for split squats?"),
                SeedMessage(sender: .other, text: "4 sets of 10 per leg, add weight once you can do all 4 clean."),
                SeedMessage(sender: .me, text: "Got it, I'll log today's session and send you the numbers after."),
            ],
            suggestions: ["leg day exercise plan", "squat depth mobility", "calf raises sets"]
        ),
        SeedChat(
            id: "chat_hiking", title: "Weekend Hiking Synchronization", emoji: "🦾",
            lastUpdatedMillis: now - 26 * 60 * 60_000,
            messages: [
                SeedMessage(sender: .me, text: "Is everyone still down for the Mount Tamalpais hike this Sunday?"),
                SeedMessage(sender: .other, text: "I'm in! What time were you thinking?"),
                SeedMessage(sender: .me, text: "7 AM start to beat the heat, back down by early afternoon."),
                SeedMessage(sender: .other, text: "Works for me — bringing extra water this time."),
                SeedMessage(sender: .other, text: "Which trailhead are we starting from?"),
                SeedMessage(sender: .me, text: "Pantoll Ranger Station, then up the Steep Ravine trail."),
                SeedMessage(sender: .other, text: "That's the one with the ladder section, right? Should be fun."),
                SeedMessage(sender: .me, text: "Yep, and great ocean views once we hit the ridge."),
                SeedMessage(sender: .other, text: "Should we pack lunch or eat after we're back down?"),
                SeedMessage(sender: .me, text: "Let's pack sandwiches — there's a nice spot near the summit to stop."),
            ],
            suggestions: ["Mount Tamalpais hike time", "Steep Ravine trailhead", "hike lunch plan"]
        ),
    ]

    private static let sampleEmails: [EmailItem] = [
        EmailItem(
            id: "email_architecture_review",
            from: "eng-lead@company.com", to: "team@company.com",
            subject: "Architecture Review Alignment",
            body: "Hi team,\n\n"
                + "I wanted to send a quick reminded that our final architecture review for the "
                + "payments migration are scheduled for Thursday at 2pm. Each team lead need to "
                + "confirms their slot by tomorrow morning. Please make sure your design docs is "
                + "uploaded to the shared folder by end of day Wednesday, since reviewers needs "
                + "time to reads through them beforehand.\n\n"
                + "There will also be two guest reviewer from the infra team joining us, so lets "
                + "keep the discussion focused and avoids going over time.\n\n"
                + "Let me know if anyone have a scheduling conflict.\n\n"
                + "Thanks,\nAlex",
            timestampMillis: now - 4 * 60 * 60_000
        ),
        EmailItem(
            id: "email_new_office",
            from: "facilities@company.com", to: "all-staff@company.com",
            subject: "Welcome to the New Office Space",
            body: "Hi all,\n\n"
                + "We is so thrilled to welcoming you to our newly renovated downtown office "
                + "building! The construction team have been working around the clock to creating "
                + "a inspiring, collaborative space. The premium barista coffee machines is fully "
                + "stocked with fresh roasted beans, the panoramic rooftop terrace is finally "
                + "opened, and the flexible hot-desking stations on floors 3 through 5 are entirely "
                + "active.\n\n"
                + "Parking passes will be distribute at the front desk starting next Monday, and "
                + "each employee need to bring a valid ID to receiving one.\n\n"
                + "Please drops by the main front reception desk at your earliest conveniences to "
                + "pick up your new RFID access badges, and join us in the main cafeteria at noon "
                + "for an complimentary catered lunch to celebrate.\n\n"
                + "Cheers,\nFacilities Department",
            timestampMillis: now - 30 * 60 * 60_000
        ),
        EmailItem(
            id: "email_compliance_training",
            from: "security-ops@company.com", to: "employee@company.com",
            subject: "Action Required: Mandatory Compliance Training",
            body: "Hi there,\n\n"
                + "This is a reminder that your annual security and compliance training remain "
                + "incomplete. All employee are required to finish the training module before the "
                + "end of this month, or your account access will be temporarily suspend.\n\n"
                + "The training take approximately 45 minutes and cover data handling, phishing "
                + "awareness, and incident reporting procedures. Managers should reminds their "
                + "direct reports during the next one-on-one, since completion rate is reviewed "
                + "by leadership each week.\n\n"
                + "Please reach out to security-ops if you experiencing any technical issues "
                + "accessing the training portal.\n\n"
                + "Regards,\nSecurity Operations",
            timestampMillis: now - 5 * 24 * 60 * 60_000
        ),
        EmailItem(
            id: "email_marketing_launch",
            from: "sarah.marketing@company.com", to: "campaign-squad@company.com",
            subject: "Meeting Notes: Marketing Campaign Launch",
            body: "Hi all,\n\n"
                + "Thank you everyone for the highly productive synchronization meetings today. "
                + "I'm distributes the minutes below.\n\n"
                + "We've officially confirm that the global product launch date are set "
                + "aggressively for next Monday. To stays on schedule, let's pleases ensures all "
                + "final creative assets, localized copy translations, and media buys is entirely "
                + "locked in and approved by legal before close of business this Friday.\n\n"
                + "Please also double check that the pricing page reflect the new discount code "
                + "before it go live.\n\n"
                + "Dave will handling the press release syndication, and Rachel will queues up the "
                + "social media post. We are rely on everyone to executing flawlessly.\n\n"
                + "Thanks for your hard work,\nSarah",
            timestampMillis: now - 2 * 60 * 60_000
        ),
        EmailItem(
            id: "email_ai_trends_newsletter",
            from: "newsletter@aitrends.com", to: "subscriber@company.com",
            subject: "Your weekly newsletter: AI Trends",
            body: "Hi,\n\n"
                + "Here is your weekly comprehensive roundup of everything happening in the "
                + "fast-paced world of Artificial Intelligence.\n\n"
                + "This week, several researcher has published papers that shows promising result "
                + "across the field, including breakthroughs showcasing how on-device quantized "
                + "models are shattering previous efficiency benchmarks, providing near real-time "
                + "generative capabilities previously isolated solely to server farms. We also "
                + "analyze the ethics surrounding algorithmic alignment, examine new open-source "
                + "diffusion techniques, and interviews the lead researcher behind the newest "
                + "on-device embedding models.\n\n"
                + "Hit the link below to dive into the full digest.\n\n"
                + "Stay curious,\nAI Trends Editor",
            timestampMillis: now - 3 * 24 * 60 * 60_000
        ),
    ]

    private static let sampleDocuments: [SeedDocument] = [
        SeedDocument(id: "doc_attention", title: "Attention Is All You Need", fileName: "attention_is_all_you_need.pdf"),
        SeedDocument(id: "doc_gpipe", title: "GPipe: Efficient Giant Model Training", fileName: "gpipe.pdf"),
        SeedDocument(
            id: "doc_multi_agent",
            title: "Multi-Agent Design: Optimizing Agents with Better Prompts and Topologies",
            fileName: "multi_agent_design.pdf"
        ),
        SeedDocument(id: "doc_contract", title: "Sample Independent Contractor Agreement", fileName: "sample_contract.pdf"),
    ]
}
