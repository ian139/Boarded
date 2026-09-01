import SwiftUI

@MainActor final class ProductProfileViewModel: ObservableObject {
    @Published var statistics = ProfileStatistics.empty
    @Published var posts: [SendFeedItem] = []
    @Published var loading = false
    @Published var error: String?
    func load(userID: UUID) async { loading=true; defer { loading=false }; do { async let stats=AppServices.profileRepository.fetchStatistics(userID:userID); async let page=AppServices.feedRepository.fetchFeed(cursor:nil, authorFilter:userID, pageSize:20); let (loadedStats, loadedPage) = try await (stats, page); statistics=loadedStats; posts=loadedPage.items } catch { self.error=error.localizedDescription } }
}

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession
    @StateObject private var model = ProductProfileViewModel()
    @State private var edit = false
    var body: some View {
        Group { if let profile=session.profile, let id=session.userId { ScrollView { VStack(alignment:.leading,spacing:AppLayout.sectionGap) { header(profile); milestone; tiles; best; ownPosts; settings }.padding(AppLayout.screenMargin).boardedContentWidth().frame(maxWidth:.infinity) }.task { await model.load(userID:id) } } else { AuthenticationView(showsDismissButton:false) } }
        .navigationTitle("Profile").boardedPageBackground().sheet(isPresented:$edit) { EditProfileView() }
    }
    private func header(_ profile:Profile)->some View { HStack(spacing:AppSpacing.space16) { BoardedAvatar(name:profile.displayName,size:72); VStack(alignment:.leading) { Text(profile.displayName).font(AppTypography.titleM); if let username=profile.username { Text("@\(username)").foregroundStyle(AppColor.textSecondary) }; if let home=profile.homeArea { Label(home,systemImage:"mappin").font(AppTypography.caption) } } }.accessibilityElement(children:.combine) }
    private var milestone:some View { VStack(alignment:.leading,spacing:AppSpacing.space8) { BoardedEyebrow(text:"Personal Best"); Text(model.statistics.bestGrade?.label ?? "Your first send starts here").font(AppTypography.displayL).foregroundStyle(model.statistics.bestGrade == nil ? AppColor.textPrimary:AppColor.accentDefault) }.boardedPanel(padding:AppLayout.featureCardPadding) }
    private var tiles:some View { LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:AppSpacing.space12) { tile("Sessions","\(model.statistics.sessionCount)","calendar"); tile("Sends","\(model.statistics.sendCount)","checkmark.circle"); tile("Send rate",model.statistics.sendRate.map(BoardedFormat.percent) ?? "—","chart.line.uptrend.xyaxis"); tile("Attempts","\(model.statistics.attemptCount)","number") } }
    private func tile(_ label:String,_ value:String,_ icon:String)->some View { VStack(alignment:.leading,spacing:AppSpacing.space8) { Image(systemName:icon).foregroundStyle(AppColor.textSecondary); Text(value).font(AppTypography.dataM); Text(label).font(AppTypography.labelM).foregroundStyle(AppColor.textSecondary) }.frame(maxWidth:.infinity,alignment:.leading).boardedPanel() }
    private var best:some View { VStack(alignment:.leading,spacing:AppSpacing.space12) { BoardedSectionHeading(title:"Best by grade",subtitle:"Highest completed grade in your journal."); if let grade=model.statistics.bestGrade { HStack { Text(grade.label).font(AppTypography.displayS); Spacer(); Text(grade.system.title).font(AppTypography.labelM).foregroundStyle(AppColor.textSecondary) } } else { Text("No completed grades yet.").foregroundStyle(AppColor.textSecondary) } } }
    private var ownPosts:some View { VStack(alignment:.leading,spacing:AppSpacing.space12) { BoardedSectionHeading(title:"Your posts"); if model.posts.isEmpty { Text("Nothing shared yet.").font(AppTypography.bodyM).foregroundStyle(AppColor.textSecondary) } else { ForEach(model.posts) { SendPostCard(item:$0,showsActions:false) } } } }
    private var settings:some View { VStack(alignment:.leading,spacing:0) { BoardedSectionHeading(title:"Settings").padding(.bottom,AppSpacing.space8); Button { edit=true } label:{ Label("Edit Profile",systemImage:"person.crop.circle").frame(maxWidth:.infinity,minHeight:56,alignment:.leading) }; Divider(); Button(role:.destructive) { Task { await session.signOut() } } label:{ Label("Sign Out",systemImage:"rectangle.portrait.and.arrow.right").frame(maxWidth:.infinity,minHeight:56,alignment:.leading) } }.buttonStyle(.plain) }
}

struct EditProfileView:View {
    @EnvironmentObject private var session:AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var name=""; @State private var username=""; @State private var bio=""; @State private var home=""; @State private var error:String?
    var body:some View { NavigationStack { ScrollView { VStack(spacing:AppSpacing.space16) { BoardedTextField(label:"Display Name",prompt:"Your name",text:$name); BoardedTextField(label:"Username",prompt:"Username",text:$username,autocapitalization:.never); BoardedTextEditor(label:"Bio",prompt:"A short climbing note",text:$bio); BoardedTextField(label:"Home Area",prompt:"Gym or climbing area",text:$home); if let error { Text(error).foregroundStyle(AppColor.danger) }; BoardedPrimaryButton(title:"Save") { save() } }.padding(AppLayout.screenMargin) }.navigationTitle("Edit Profile").toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() } } }.boardedPageBackground().onAppear { name=session.profile?.fullName ?? ""; username=session.profile?.username ?? ""; bio=session.profile?.bio ?? ""; home=session.profile?.homeArea ?? "" } } }
    private func save(){ let cleanName=name.trimmingCharacters(in:.whitespacesAndNewlines); let cleanUsername=username.trimmingCharacters(in:.whitespacesAndNewlines); guard !cleanName.isEmpty,!cleanUsername.isEmpty else { error="Display name and username are required.";return }; Task { do { try await session.updateProfile(fullName:cleanName,username:cleanUsername,bio:bio,homeArea:home);dismiss() } catch { self.error=error.localizedDescription } } }
}
