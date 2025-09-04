//
//  ShareViewController.swift
//  ShareExtension
//
//  Share Extension for saving URLs to Limit
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    private var url: URL?
    private var selectedAction = "bookmark" // Default action
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set placeholder text
        textView.text = ""
        placeholder = "Add a note (optional)"
        
        // Extract URL from shared content
        extractURL()
    }
    
    
    private func extractURL() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        
        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }
            
            for attachment in attachments {
                // Check for URL type
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                        if let url = item as? URL {
                            self?.url = url
                        } else if let urlString = item as? String, let url = URL(string: urlString) {
                            self?.url = url
                        }
                        
                        DispatchQueue.main.async {
                            self?.validateContent()
                        }
                    }
                    return
                }
                // Check for text that might be a URL
                else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                        if let text = item as? String {
                            self?.url = self?.extractURLFromText(text)
                        }
                        
                        DispatchQueue.main.async {
                            self?.validateContent()
                        }
                    }
                    return
                }
            }
        }
    }
    
    private func extractURLFromText(_ text: String) -> URL? {
        // Try to create URL directly
        if let url = URL(string: text), url.scheme != nil {
            return url
        }
        
        // Try to find URL in text using data detector
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        if let match = matches?.first, let url = match.url {
            return url
        }
        
        // If no scheme, try adding https://
        if !text.isEmpty && !text.contains("://") {
            let urlString = "https://\(text)"
            return URL(string: urlString)
        }
        
        return nil
    }
    
    override func isContentValid() -> Bool {
        // Enable Post button only if we have a URL
        return url != nil
    }
    
    override func didSelectPost() {
        guard let url = url else {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        // Save to App Groups
        let sharedDefaults = UserDefaults(suiteName: "group.P24L.Limit.dev")
        sharedDefaults?.set(url.absoluteString, forKey: "pendingURL")
        sharedDefaults?.set(selectedAction, forKey: "pendingAction")
        
        // Save the optional note if user added one
        if let note = textView.text, !note.isEmpty {
            sharedDefaults?.set(note, forKey: "pendingNote")
        }
        
        // Synchronize to ensure data is written
        sharedDefaults?.synchronize()
        
        // Complete the request
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    override func configurationItems() -> [Any]! {
        guard let actionItem = SLComposeSheetConfigurationItem() else { return [] }
        
        actionItem.title = "Save as"
        actionItem.value = selectedAction == "bookmark" ? "Bookmark" : "Post"
        
        actionItem.tapHandler = { [weak self] in
            guard let self = self else { return }
            
            let alertController = UIAlertController(title: "Choose Action", message: nil, preferredStyle: .actionSheet)
            
            alertController.addAction(UIAlertAction(title: "Save as Bookmark", style: .default) { _ in
                self.selectedAction = "bookmark"
                self.reloadConfigurationItems()
                self.validateContent()
            })
            
            alertController.addAction(UIAlertAction(title: "Create New Post", style: .default) { _ in
                self.selectedAction = "post"
                self.reloadConfigurationItems()
                self.validateContent()
            })
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // For iPad
            if let popover = alertController.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            self.present(alertController, animated: true)
        }
        
        return [actionItem]
    }
}