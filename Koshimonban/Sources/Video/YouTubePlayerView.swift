import SwiftUI
import WebKit

/// YouTube を IFrame Player API で再生する。
///
/// 単純に embed URL を読み込む方式は採らない。埋め込み禁止・地域制限・自動再生ブロックが
/// どれも「読み込み成功」に見えてしまい、失敗を検出できないため。
/// API のイベントを JS から Swift に返し、実際に再生が始まったことを確認する。
struct YouTubePlayerView: NSViewRepresentable {

    let videoID: String
    let state: VideoPlaybackState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // 自動再生のためにユーザー操作の要求を外す
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // 休憩のたびに cookie を溜めない
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "player")
        context.coordinator.userContentController = configuration.userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false

        state.beginWaitingForPlayback()
        webView.loadHTMLString(Self.html(videoID: videoID),
                               baseURL: URL(string: "https://www.youtube-nocookie.com"))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) { }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.userContentController?.removeScriptMessageHandler(forName: "player")
        coordinator.userContentController = nil
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    // MARK: JS からの通知を受ける

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private let state: VideoPlaybackState
        /// 登録したコントローラそのものを控える。
        /// `webView.configuration` はコピーを返すため、そちら経由の解除は
        /// 同じインスタンスに届く保証がない。届かないと WebKit 側から
        /// この Coordinator が参照されたまま残る。
        fileprivate var userContentController: WKUserContentController?

        init(state: VideoPlaybackState) { self.state = state }

        deinit {
            userContentController?.removeScriptMessageHandler(forName: "player")
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            let detail = body["detail"] as? String

            MainActor.assumeIsolated {
                switch type {
                case "state":
                    // 1 = 再生中。ここに到達して初めて「本当に再生できた」と言える。
                    if detail == "1" { state.markPlaying() }
                case "error":
                    state.markFailed(Self.describe(errorCode: detail))
                default:
                    break
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            MainActor.assumeIsolated { state.markFailed(error.localizedDescription) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            MainActor.assumeIsolated { state.markFailed(error.localizedDescription) }
        }

        private static func describe(errorCode: String?) -> String {
            switch errorCode {
            case "2":         "動画 ID が正しくありません"
            case "5":         "この動画はプレイヤーで再生できません"
            case "100":       "動画が見つかりません（削除または非公開）"
            case "101", "150": "この動画は埋め込み再生が許可されていません"
            case "api-load-failed": "YouTube に接続できませんでした"
            case .some(let other): "再生エラー（\(other)）"
            case .none:       "再生エラー"
            }
        }
    }

    // MARK: 埋め込み用 HTML

    private static func html(videoID: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            html, body { margin:0; padding:0; background:#0d0f19; overflow:hidden; }
            #player { width:100vw; height:100vh; }
          </style>
        </head>
        <body>
          <div id="player"></div>
          <script>
            function post(type, detail) {
              try {
                window.webkit.messageHandlers.player.postMessage({
                  type: type,
                  detail: (detail === null || detail === undefined) ? null : String(detail)
                });
              } catch (e) {}
            }

            var player;
            var unmuted = false;

            function onYouTubeIframeAPIReady() {
              player = new YT.Player('player', {
                videoId: '\(videoID)',
                host: 'https://www.youtube-nocookie.com',
                playerVars: {
                  autoplay: 1, rel: 0, modestbranding: 1,
                  playsinline: 1, controls: 1, fs: 0,
                  origin: 'https://www.youtube-nocookie.com'
                },
                events: {
                  onReady: function (e) {
                    // 音ありの自動再生は弾かれることがあるため、まず消音で始める。
                    // 再生が始まってから音を戻す（音量はプレイヤー既定のまま触らない）。
                    try { e.target.mute(); e.target.playVideo(); } catch (err) { post('error', 'play:' + err); }
                  },
                  onStateChange: function (e) {
                    post('state', e.data);
                    if (e.data === 1 && !unmuted) {
                      unmuted = true;
                      try { player.unMute(); } catch (err) {}
                    }
                  },
                  onError: function (e) { post('error', e.data); }
                }
              });
            }

            window.onerror = function (message) { post('error', 'js:' + message); };

            var tag = document.createElement('script');
            tag.src = 'https://www.youtube.com/iframe_api';
            tag.onerror = function () { post('error', 'api-load-failed'); };
            document.head.appendChild(tag);
          </script>
        </body>
        </html>
        """
    }
}
