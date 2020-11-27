import UIKit


class PostFeedCell: UITableViewCell {
    
    @IBOutlet private var profilePictureView: ProfilePictureView!
    @IBOutlet private var userNameLabel: UILabel!
    @IBOutlet private var userLocationLabel: UILabel!
    @IBOutlet private var postImageView: AsynchronousImageView!
    @IBOutlet private var likeButton: UIButton!
    @IBOutlet private var commentButton: UIButton!
    @IBOutlet private var bookmarkButton: UIButton!
    @IBOutlet private var showLikersButton: UIButton!
    @IBOutlet private var likerFolloweeProfilePictureView: ProfilePictureView!
    @IBOutlet private var likesLabel: UILabel!
    @IBOutlet private var captionLabel: UILabel!
    @IBOutlet private var commentCountLabel: UILabel!
    @IBOutlet private var dateLabel: UILabel!
    weak var viewController: UIViewController?
    
    var post: Post!
    func setPost(_ newPost: Post) {
        self.post = newPost
        
        self.profilePictureView.showImageAsynchronously(imageURL: newPost.user.profilePictureURL)
        self.postImageView.showImageAsynchronously(imageURL: newPost.images?.first?.url)
        
        self.userNameLabel.text = newPost.user.userName
        self.userLocationLabel.text = newPost.location
        self.updateLikes()
        self.bookmarkButton.isSelected = newPost.isSaved
        self.captionLabel.text = newPost.caption
        if newPost.comments.count > 0 {
            self.commentCountLabel.text = "View all \(newPost.comments.count) comments"
            self.commentCountLabel.isHidden = false
        } else {
            self.commentCountLabel.isHidden = true
        }
        self.dateLabel.text = newPost.date.stringRepresentation
    }
    
    private func updateLikes() {
        self.likeButton.isSelected = self.post.isLiked
        let likerFollowee = self.post.likerFollowee
        self.likerFolloweeProfilePictureView.showImageAsynchronously(imageURL: likerFollowee?.profilePictureURL)
        if likerFollowee != nil {
            self.likerFolloweeProfilePictureView.isHidden = false
            let textTemplate = (self.post.numberOfLikes > 1) ? "Liked by {user} and {others}" : "Liked by {user}"
            let text = NSMutableAttributedString(string: textTemplate, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12, weight: UIFont.Weight.regular)])
            if let characterRange = text.string.range(of: "{others}") {
                text.replaceCharacters(in: NSRange(characterRange, in: text.string), with: NSAttributedString(string: "\(self.post.numberOfLikes - 1) others", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12, weight: UIFont.Weight.bold)]))
            }
            if let characterRange = text.string.range(of: "{user}") {
                text.replaceCharacters(in: NSRange(characterRange, in: text.string), with: NSAttributedString(string: likerFollowee!.userName, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12, weight: UIFont.Weight.bold)]))
            }
            self.likesLabel.attributedText = text
        } else {
            self.likerFolloweeProfilePictureView.isHidden = true
            self.likesLabel.text = "\(self.post.numberOfLikes) likes"
        }
        self.showLikersButton.isHidden = (self.post.numberOfLikes == 0)
    }
    
    @IBAction private func showUserProfile() {
        let userProfileViewer = UserProfileViewController(user: self.post.user)
        self.viewController?.navigationController?.pushViewController(userProfileViewer, animated: true)
    }
    
    @IBAction private func toggleLike() {
        self.post.toggleLike()
        self.updateLikes()
        
        let thePostToUpdate = self.post!
        ServerAPI.shared.updatePostLike(self.post, completion: { (updatedPost: Post?, error: Error?) in
            if error != nil {
                self.viewController?.report(error: error)
                thePostToUpdate.toggleLike()
            }
            if self.post == thePostToUpdate {
                self.setPost(thePostToUpdate)
            }
        })
    }
    
    @IBAction private func toggleSaved() {
        self.post.toggleSaved()
        self.bookmarkButton.isSelected = self.post.isSaved
        
        let thePostToUpdate = self.post!
        ServerAPI.shared.updatePostSaved(self.post, completion: { (updatedPost: Post?, error: Error?) in
            if error != nil {
                self.viewController?.report(error: error)
                thePostToUpdate.toggleSaved()
            }
            if self.post == thePostToUpdate {
                self.setPost(thePostToUpdate)
            }
        })
    }
    
    @IBAction private func addComment() {
        let commentsViewController = CommentsViewController(post: self.post)
        self.viewController?.navigationController?.pushViewController(commentsViewController, animated: true)
    }
    
    @IBAction private func showAllComments() {
        let commentsViewController = CommentsViewController(post: self.post)
        self.viewController?.navigationController?.pushViewController(commentsViewController, animated: true)
    }
    
    @IBAction private func showLikers() {
        if self.post.numberOfLikes > 0 {
            let userListViewController = UserListViewController(UserKind.likers(self.post))
            self.viewController?.navigationController?.pushViewController(userListViewController, animated: true)
        }
    }
    
    @IBAction private func showOptions() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        if self.post.user == User.current {
            alert.addAction(UIAlertAction(title: "Edit Post", style: UIAlertAction.Style.default, handler: { (_: UIAlertAction) in
                let postEditor = PostEditorController(post: self.post, cachedPostImage: self.postImageView.image) { (updatedPost: Post?) in
                    var view = self as UIView?
                    while !(view is UITableView) {
                        view = view?.superview
                    }
                    if let tableView = (view as? UITableView) {
                        tableView.reloadData()
                    }
                    self.viewController?.dismiss(animated: true, completion: nil)
                }
                let navigationController = UINavigationController(rootViewController: postEditor)
                navigationController.modalPresentationStyle = UIModalPresentationStyle.fullScreen
                navigationController.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
                self.viewController?.present(navigationController, animated: true, completion: nil)
            }))
            alert.addAction(UIAlertAction(title: "Delete Post", style: UIAlertAction.Style.destructive, handler: { (_: UIAlertAction) in
                ServerAPI.shared.deletePost(self.post) { (error: Error?) in
                    if error == nil {
                        NotificationCenter.default.post(name: Notification.Name.PostDeletedNotification, object: self.post)
                    } else {
                        self.viewController?.report(error: error)
                    }
                }
            }))
        } else {
            let likeActionTitle = self.post.isLiked ? "Unlike" : "Like"
            alert.addAction(UIAlertAction(title: likeActionTitle, style: UIAlertAction.Style.default, handler: { (_: UIAlertAction) in
                self.toggleLike()
            }))
            let saveActionTitle = self.post.isSaved ? "Remove from Saved" : "Save"
            alert.addAction(UIAlertAction(title: saveActionTitle, style: UIAlertAction.Style.default, handler: { (_: UIAlertAction) in
                self.toggleSaved()
            }))
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
        self.viewController?.present(alert, animated: true, completion: nil)
    }
}


extension Notification.Name {
    public static let PostDeletedNotification = NSNotification.Name("Post deleted")
}
