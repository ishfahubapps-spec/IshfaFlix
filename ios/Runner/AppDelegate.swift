import UIKit
import AVKit
import Flutter
// import GoogleCast

@main
@objc class AppDelegate: FlutterAppDelegate {
    // let kReceiverAppID = kGCKDefaultMediaReceiverApplicationID
    let kDebugLoggingEnabled = true
    var pipController: AVPictureInPictureController?
    var playerViewController: AVPlayerViewController?
    var player: AVPlayer?
    
    var isPlaying: Bool = false // Track playback status
    var playbackPosition: Int = 0 // Track playback position
    var videoUrl: String? // Track video URL

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        // let criteria = GCKDiscoveryCriteria(applicationID: kReceiverAppID)
        // let options = GCKCastOptions(discoveryCriteria: criteria)
        // GCKCastContext.setSharedInstanceWith(options)
        // GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true
        // GCKLogger.sharedInstance().delegate = self

        let controller = window?.rootViewController as! FlutterViewController
        let pipChannel = FlutterMethodChannel(name: "com.example.yourappname/pip", binaryMessenger: controller.binaryMessenger)

        pipChannel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "updateVideoState", let args = call.arguments as? [String: Any] {
                self?.isPlaying = args["isPlaying"] as? Bool ?? false
                self?.playbackPosition = args["position"] as? Int ?? 0
                self?.videoUrl = args["videoUrl"] as? String
                print("Received video state - isPlaying: \(self?.isPlaying ?? false), position: \(self?.playbackPosition ?? 0)")
                result(nil)
            } else if call.method == "videoProgress", let args = call.arguments as? [String: Any] {
                self?.playbackPosition = args["position"] as? Int ?? 0
                print("Received video position: \(self?.playbackPosition ?? 0)")
                result(nil)
            } else if call.method == "enterPipMode", let args = call.arguments as? [String: Any] {
                self?.playbackPosition = args["position"] as? Int ?? 0
                self?.videoUrl = args["videoUrl"] as? String
                print("Received video position: \(self?.playbackPosition ?? 0)")
                guard let self = self else { return }
                self.enterPipMode()
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func applicationWillResignActive(_ application: UIApplication) {
        print("App going to background. Checking PIP mode...")
        if isPlaying {
            enterPipMode()
        } else {
            print("Skipping PIP mode - No video playing.")
        }
    }

    func enterPipMode() {
        guard let videoUrl = videoUrl else {
            print("No video URL provided, skipping PIP.")
            return
        }

        guard let rootVC = window?.rootViewController else {
            print("No rootViewController found.")
            return
        }

        DispatchQueue.main.async {
            guard let url = URL(string: videoUrl) else {
                print("Invalid video URL: \(videoUrl)")
                return
            }
            if self.player == nil {
                self.player = AVPlayer(url: url)
            }

            if let player = self.player {
                player.seek(to: CMTime(seconds: Double(self.playbackPosition), preferredTimescale: 1))
                print("Seeking video to \(self.playbackPosition) seconds")
                player.play()
            }

            let playerVC = AVPlayerViewController()
            playerVC.player = self.player
            rootVC.present(playerVC, animated: true) { [weak self] in
                if AVPictureInPictureController.isPictureInPictureSupported() {
                    self?.pipController = AVPictureInPictureController(playerLayer: AVPlayerLayer(player: self?.player))
                    
                    if let pipController = self?.pipController {
                        pipController.startPictureInPicture()
                        print("PIP Mode Started")
                    } else {
                        print("Failed to initialize PIP Controller.")
                    }
                } else {
                    print("PIP not supported on this device.")
                }
            }
        }
    }
    
    override func applicationDidEnterBackground(_ application: UIApplication) {
        print("App entered background. Checking PIP mode...")
        if let pipController = pipController, pipController.isPictureInPictureActive == false {
            pipController.startPictureInPicture()
        }
    }
}
