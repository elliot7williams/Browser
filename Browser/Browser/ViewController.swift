//
//  ViewController.swift
//  Browser
//
//  Created by Elliot Williams on 2025-06-29.
//

import UIKit
import GameKit

class ViewController: GCEventViewController {
    // MARK: - IBOutlets
    @IBOutlet weak var topMenuView: UIVisualEffectView!
    @IBOutlet weak var browserContainerView: UIView!
    @IBOutlet weak var btnImageBack: UIImageView!
    @IBOutlet weak var btnImageForward: UIImageView!
    @IBOutlet weak var btnImageRefresh: UIImageView!
    @IBOutlet weak var btnImageHome: UIImageView!
    @IBOutlet weak var btnImageFullScreen: UIImageView!
    @IBOutlet weak var btnImgMenu: UIImageView!
    @IBOutlet weak var lblUrlBar: UILabel!
    @IBOutlet weak var loadingSpinner: UIActivityIndicatorView!
    
    // MARK: - Properties
    private var webView: UIWebView!
    private var requestURL: String?
    private var previousURL: String?
    private var cursorView: UIImageView!
    private var cursorMode = true
    private var displayedHintsOnLaunch = false
    private var scrollViewAllowBounces = true
    private var lastTouchLocation = CGPoint(x: -1, y: -1)
    private var textFontSize: UInt = 100 {
        didSet {
            textFontSize = min(200, max(50, textFontSize))
            updateTextFontSize()
        }
    }
    
    private var touchSurfaceDoubleTapRecognizer: UITapGestureRecognizer!
    private var playPauseDoubleTapRecognizer: UITapGestureRecognizer!
    
    // MARK: - Computed Properties
    private var topMenuShowing: Bool {
        return !topMenuView.isHidden
    }
    
    private var topMenuBrowserOffset: CGFloat {
        return topMenuShowing ? topMenuView.frame.height : 0
    }
    
    // MARK: - View Lifecycle
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        webViewDidAppear()
        displayedHintsOnLaunch = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        definesPresentationContext = true
        initWebView()
        setupGestureRecognizers()
        setupCursorView()
        setupLoadingSpinner()
        restoreFontSize()
    }
    
    // MARK: - Setup
    private func initWebView() {
        webView = UIWebView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.clipsToBounds = false
        browserContainerView.addSubview(webView)
        
        webView.frame = view.bounds
        webView.delegate = self
        webView.layoutMargins = .zero
        
        if let scrollView = webView.scrollView {
            scrollView.layoutMargins = .zero
            if #available(tvOS 11.0, *) {
                scrollView.contentInsetAdjustmentBehavior = .never
            } else {
                automaticallyAdjustsScrollViewInsets = false
            }
            
            scrollView.contentOffset = .zero
            scrollView.contentInset = .zero
            scrollView.frame = view.bounds
            scrollView.clipsToBounds = false
            scrollView.bounces = scrollViewAllowBounces
            scrollView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
            scrollView.isScrollEnabled = false
        }
        
        webView.isUserInteractionEnabled = false
        
        let showTopNavBar = UserDefaults.standard.object(forKey: "ShowTopNavigationBar") as? Bool ?? true
        topMenuView.isHidden = !showTopNavBar
        updateTopNavAndWebView()
    }
    
    private func setupGestureRecognizers() {
        touchSurfaceDoubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTouchSurfaceDoubleTap(_:)))
        touchSurfaceDoubleTapRecognizer.numberOfTapsRequired = 2
        touchSurfaceDoubleTapRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        view.addGestureRecognizer(touchSurfaceDoubleTapRecognizer)
        
        playPauseDoubleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handlePlayPauseDoubleTap(_:)))
        playPauseDoubleTapRecognizer.numberOfTapsRequired = 2
        playPauseDoubleTapRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        view.addGestureRecognizer(playPauseDoubleTapRecognizer)
    }
    
    private func setupCursorView() {
        cursorView = UIImageView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        cursorView.center = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        cursorView.image = kDefaultCursor()
        view.addSubview(cursorView)
    }
    
    private func setupLoadingSpinner() {
        loadingSpinner.hidesWhenStopped = true
    }
    
    private func restoreFontSize() {
        let fontSize = UserDefaults.standard.object(forKey: "TextFontSize") as? UInt ?? 100
        textFontSize = min(200, max(50, fontSize))
    }
    
    // MARK: - Font Size Management
    private func updateTextFontSize() {
        let jsString = "document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust='\(textFontSize)%'"
        webView.stringByEvaluatingJavaScript(from: jsString)
        UserDefaults.standard.set(textFontSize, forKey: "TextFontSize")
    }
    
    // MARK: - Navigation Bar
    private func updateTopNavAndWebView() {
        if topMenuShowing {
            webView.frame = CGRect(
                x: view.bounds.origin.x,
                y: view.bounds.origin.y + topMenuBrowserOffset,
                width: view.bounds.width,
                height: view.bounds.height - topMenuBrowserOffset
            )
        } else {
            webView.frame = view.bounds
        }
    }
    
    private func hideTopNav() {
        topMenuView.isHidden = true
        updateTopNavAndWebView()
        UserDefaults.standard.set(false, forKey: "ShowTopNavigationBar")
    }
    
    private func showTopNav() {
        topMenuView.isHidden = false
        updateTopNavAndWebView()
        UserDefaults.standard.set(true, forKey: "ShowTopNavigationBar")
    }
    
    // MARK: - WebView Management
    func webViewDidAppear() {
        if let savedURL = UserDefaults.standard.string(forKey: "savedURLtoReopen") {
            webView.loadRequest(URLRequest(url: URL(string: savedURL)!)
            UserDefaults.standard.removeObject(forKey: "savedURLtoReopen")
        } else if webView.request == nil {
            loadHomePage()
        }
        
        if !UserDefaults.standard.bool(forKey: "DontShowHintsOnLaunch") && !displayedHintsOnLaunch {
            showHintsAlert()
        }
    }
    
    private func loadHomePage() {
        let homepage = UserDefaults.standard.string(forKey: "homepage") ?? "http://www.google.com"
        webView.loadRequest(URLRequest(url: URL(string: homepage)!)
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleTouchSurfaceDoubleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            toggleMode()
        }
    }
    
    @objc private func handlePlayPauseDoubleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            showAdvancedMenu()
        }
    }
    
    // MARK: - Cursor Mode
    private func toggleMode() {
        cursorMode.toggle()
        webView.scrollView.isScrollEnabled = !cursorMode
        webView.isUserInteractionEnabled = !cursorMode
        cursorView.isHidden = !cursorMode
    }
    
    // MARK: - Alert Controllers
    private func showHintsAlert() {
        let alert = UIAlertController(
            title: "Usage Guide",
            message: "Double press the touch area to switch between cursor & scroll mode.\nPress the touch area while in cursor mode to click.\nSingle tap to Menu button to Go Back, or Exit on root page.\nSingle tap the Play/Pause button to: Go Forward, Enter URL or Reload Page.\nDouble tap the Play/Pause to show the Advanced Menu with more options.",
            preferredStyle: .alert
        )
        
        let hideAction = UIAlertAction(
            title: "Don't Show This Again",
            style: .destructive
        ) { _ in
            UserDefaults.standard.set(true, forKey: "DontShowHintsOnLaunch")
        }
        
        let showAction = UIAlertAction(
            title: "Always Show On Launch",
            style: .destructive
        ) { _ in
            UserDefaults.standard.set(false, forKey: "DontShowHintsOnLaunch")
        }
        
        let cancelAction = UIAlertAction(title: "Dismiss", style: .cancel)
        
        if UserDefaults.standard.bool(forKey: "DontShowHintsOnLaunch") {
            alert.addAction(showAction)
        } else {
            alert.addAction(hideAction)
        }
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    // ... Other methods (showAdvancedMenu, requestURLorSearchInput, etc) ...
    // These would be implemented similarly to their Objective-C counterparts
    // using UIAlertController and appropriate Swift syntax
}

// MARK: - UIWebViewDelegate
extension ViewController: UIWebViewDelegate {
    func webViewDidStartLoad(_ webView: UIWebView) {
        if previousURL != requestURL {
            loadingSpinner.startAnimating()
        }
        previousURL = requestURL
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        loadingSpinner.stopAnimating()
        if let url = webView.request?.url?.absoluteString {
            lblUrlBar.text = url
            updateTextFontSize()
            saveToHistory(url: url, title: webView.stringByEvaluatingJavaScript(from: "document.title") ?? "")
        }
    }
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        requestURL = request.url?.absoluteString
        return true
    }
    
    private func saveToHistory(url: String, title: String) {
        var history = UserDefaults.standard.array(forKey: "HISTORY") as? [[String]] ?? []
        history.insert([url, title], at: 0)
        
        while history.count > 100 {
            history.removeLast()
        }
        
        UserDefaults.standard.set(history, forKey: "HISTORY")
    }
}

// MARK: - Helper Functions
private func kTextColor() -> UIColor {
    if #available(tvOS 13.0, *) {
        return .label
    } else {
        return .black
    }
}

private func kDefaultCursor() -> UIImage {
    return UIImage(named: "Cursor")!
}

private func kPointerCursor() -> UIImage {
    return UIImage(named: "Pointer")!
}
