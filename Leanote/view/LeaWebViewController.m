#import "LeaWebViewController.h"
//#import "WordPressAppDelegate.h"
#import "ReachabilityUtils.h"
//#import "WPActivityDefaults.h"
#import "NSString+Helpers.h"
//#import "UIDevice+Helpers.h"
#import "LeaURLRequest.h"
//#import "WPUserAgent.h"
//#import "WPCookie.h"
//#import "Constants.h"
#import "LeaAlert.h"

/*
 WPWebViewController.m
 https://github.com/wordpress-mobile/WordPress-iOS/blob/8ff4b5b18c638f6b592018f277616db2734de2cb/WordPress/Classes/Utility/WPWebViewController.m
 block回调: https://www.jianshu.com/p/d911cd16c100
 Xcode11-闪退错误Could not instantiate class named WKWebView https://www.bilibili.com/read/cv3184836/
 
 iOS-手动添加限制-constraints	https://blog.csdn.net/wang1514869032/article/details/52164199
 contstrait https://blog.csdn.net/jason_chen13/article/details/52869540
*/

#import "Common.h"

// https://github.com/iDay/WeixinActivity
#import "WeixinActivity.h"

#import <WordPress-iOS-Shared/WordPressShared/WPStyleGuide.h>
#import <WordPress-iOS-Shared/WordPressShared/NSString+Util.h>


@class WPReaderDetailViewController;

@interface LeaWebViewController () <UIPopoverControllerDelegate>

@property (nonatomic, weak, readonly) UIScrollView *scrollView;
@property (nonatomic, strong) UIPopoverController *popover;
@property (nonatomic, assign) BOOL isLoading;

@property (nonatomic, assign) BOOL hasLoadedContent;

@property (nonatomic, strong)  UIBarButtonItem   *dismissButton;

@end

@implementation LeaWebViewController

- (void)dealloc
{
	_webView.UIDelegate = nil;
	_webView.navigationDelegate = nil;
    if (_webView.isLoading) {
        [_webView stopLoading];
    }
    _statusTimer = nil;
}

- (BOOL)hidesBottomBarWhenPushed
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	// 创建网页配置对象
	WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
	// 创建设置对象
	WKPreferences *preference = [[WKPreferences alloc]init];
	// 最小字体大小 当将javaScriptEnabled属性设置为NO时，可以看到明显的效果
	preference.minimumFontSize = 0;
	// 设置是否支持javaScript 默认是支持的
	preference.javaScriptEnabled = YES;
	// 在iOS上默认为NO，表示是否允许不经过用户交互由javaScript自动打开窗口
	preference.javaScriptCanOpenWindowsAutomatically = YES;
	config.preferences = preference;
	// 是使用h5的视频播放器在线播放, 还是使用原生播放器全屏播放
	config.allowsInlineMediaPlayback = YES;
	// 设置视频是否需要用户手动播放  设置为NO则会允许自动播放
	config.requiresUserActionForMediaPlayback = YES;
	// 设置是否允许画中画技术 在特定设备上有效
	config.allowsPictureInPictureMediaPlayback = YES;
	
	self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
	
//	self.webView = [[WKWebView alloc] init];
//	self.view.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:_webView];
	
	NSDictionary *dic = @{
		@"webView":self.webView
	};
	
	NSString *vfl = @"V:|-0-[webView]-44-|"; // 上0, 下44
	NSString *vfl1 = @"H:|-0-[webView]-0-|"; // 左右为0
	_webView.translatesAutoresizingMaskIntoConstraints = NO;
	
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:vfl options:0 metrics:nil views:dic]];
	[self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:vfl1 options:0 metrics:nil views:dic]];
	
	// 加了这一句 delegate才有用 didStartProvisionalNavigation !!!
	self.webView.navigationDelegate = self;

//    if (IS_IPHONE) {
        self.navigationItem.title = NSLocalizedString(@"Loading...", @"");
//    }

    [self setLoading:NO];
    self.backButton.enabled = NO;
    self.forwardButton.enabled = NO;
    self.backButton.accessibilityLabel = NSLocalizedString(@"Back", @"Spoken accessibility label");
    self.forwardButton.accessibilityLabel = NSLocalizedString(@"Forward", @"Spoken accessibility label");
    self.refreshButton.accessibilityLabel = NSLocalizedString(@"Refresh", @"Spoken accessibility label");

//    if (IS_IPHONE) {
        if (!self.hidesLinkOptions) {
            [WPStyleGuide setRightBarButtonItemWithCorrectSpacing:self.optionsButton forNavigationItem:self.navigationItem];
        }
	/*
	// IPAD
    } else {
        // We want the refresh button to be borderless, but buttons in navbars want a border.
        // We need to compose the refresh button as a UIButton that is used as the UIBarButtonItem's custom view.
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setImage:[UIImage imageNamed:@"sync_lite"] forState:UIControlStateNormal];
        [btn setImage:[UIImage imageNamed:@"sync"] forState:UIControlStateHighlighted];

        btn.frame = CGRectMake(0.0f, 0.0f, 30.0f, 30.0f);
        btn.autoresizingMask =  UIViewAutoresizingFlexibleHeight;
        [btn addTarget:self action:@selector(reload) forControlEvents:UIControlEventTouchUpInside];
        self.refreshButton.customView = btn;

        if (self.navigationController && self.navigationController.navigationBarHidden == NO) {
            CGRect frame = self.webView.frame;
            frame.origin.y -= self.iPadNavBar.frame.size.height;
            frame.size.height += self.iPadNavBar.frame.size.height;
            self.webView.frame = frame;
            self.navigationItem.rightBarButtonItem = self.refreshButton;
            self.title = NSLocalizedString(@"Loading...", @"");
            [self.iPadNavBar removeFromSuperview];
            self.iPadNavBar = self.navigationController.navigationBar;
        } else {
            self.refreshButton.customView = btn;
            self.iPadNavBar.topItem.title = NSLocalizedString(@"Loading...", @"");
        }
        self.loadingLabel.text = NSLocalizedString(@"Loading...", @"");
    }
	*/

	// 底部工具栏
    self.toolbar.translucent = NO;
    self.toolbar.barTintColor = [WPStyleGuide littleEddieGrey]; // 暗
    self.toolbar.tintColor = [UIColor whiteColor];

	// 右上角分享
    self.optionsButton.enabled = NO;
	
//    self.webView.scalesPageToFit = YES;
    self.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;

    if (self.url) {
    } else {
		self.url = [NSURL URLWithString:@"https://leanote.com"];
//        [self.webView loadHTMLString:self.detailHTML baseURL:];
    }
	[self refreshWebView];
	// self.navigationItem.title = NSLocalizedString(@"Loading...", @"");
	
	// 如果是modal来的, 没有back
	if(self.presentingViewController) {
		/*
		self.dismissButton =
		[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", nil)
										 style:UIBarButtonItemStyleBordered
										target:self
										action:@selector(back)];
		*/
		
		UIImage *image = [[UIImage imageNamed:@"icon-cross"] imageWithRenderingMode:UIImageRenderingModeAutomatic]; // 必须要设置UIImageRenderingModeAutomatic, 不然tintColor没用
		UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(back)];
		button.tintColor = [UIColor whiteColor];
		// 向下移4
		float topInset = .0f;
		button.imageInsets = UIEdgeInsetsMake(topInset, 0.0f, -topInset, 0.0f);
		self.navigationItem.leftBarButtonItem = button; // self.dismissButton;
		
		/*
		UIButton *button2 =  [UIButton buttonWithType:UIButtonTypeCustom];
		[button2 setImage:[UIImage imageNamed:@"icon-cross"] forState:UIControlStateNormal];
		[button2 addTarget:self action:@selector(back)forControlEvents:UIControlEventTouchUpInside];
		[button2 setFrame:CGRectMake(0, 0, 53, 31)];
		button2.tintColor = [UIColor whiteColor];
		
		UIBarButtonItem *barButton = [[UIBarButtonItem alloc] initWithCustomView:button2];
		barButton.tintColor = [UIColor whiteColor];
		self.navigationItem.leftBarButtonItem = barButton;
		*/
	}
	
	// 每次打开都重新登录下
	self.needsLogin = true;
}

- (void) back
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
//    DDLogMethod()
    [super viewWillAppear:animated];

    if ( self.detailContent == nil ) {
        [self setStatusTimer:[NSTimer timerWithTimeInterval:0.75 target:self selector:@selector(upgradeButtonsAndLabels:) userInfo:nil repeats:YES]];
        [[NSRunLoop currentRunLoop] addTimer:[self statusTimer] forMode:NSDefaultRunLoopMode];
    } else {
        //do not set the timer on the detailsView
        //change the arrows to up/down icons
        [self.backButton setImage:[UIImage imageNamed:@"previous.png"]];
        [self.forwardButton setImage:[UIImage imageNamed:@"next.png"]];

        // Replace refresh button with options button
        self.backButton.width = (self.toolbar.frame.size.width / 2.0f) - 10.0f;
        self.forwardButton.width = (self.toolbar.frame.size.width / 2.0f) - 10.0f;
        UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        NSArray *items = @[spacer, self.backButton, spacer, self.forwardButton, spacer];
        self.toolbar.items = items;
    }
	
	[Common setBarStyleLight];
}

- (void)viewWillDisappear:(BOOL)animated
{
//    DDLogMethod()
    [self setStatusTimer:nil];
    [super viewWillDisappear:animated];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    CGFloat height = self.navigationController.navigationBar.frame.size.height;
    CGRect customToolbarFrame = self.toolbar.frame;
    customToolbarFrame.size.height = height;
    customToolbarFrame.origin.y = self.toolbar.superview.bounds.size.height - height;

    CGRect webFrame = self.webView.frame;
    webFrame.size.height = customToolbarFrame.origin.y;

    [UIView animateWithDuration:duration animations:^{
        self.toolbar.frame = customToolbarFrame;
        self.webView.frame = webFrame;
    }];
}

- (BOOL)expectsWidePanel
{
    return YES;
}

- (UIBarButtonItem *)optionsButton
{
    if (_optionsButton) {
        return _optionsButton;
    }
    UIImage *image = [UIImage imageNamed:@"icon-posts-share"];
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, image.size.width, image.size.height)];
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:self action:@selector(showLinkOptions) forControlEvents:UIControlEventTouchUpInside];
    _optionsButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    _optionsButton.accessibilityLabel = NSLocalizedString(@"Share", @"Spoken accessibility label");
    return _optionsButton;
}

#pragma mark - webView related methods

- (void)setStatusTimer:(NSTimer *)timer
{
    if (_statusTimer && timer != _statusTimer) {
        [_statusTimer invalidate];
    }
    _statusTimer = timer;
}

- (void)upgradeButtonsAndLabels:(NSTimer*)timer
{
	[self refreshInterface];
	return;
	
    self.backButton.enabled = self.webView.canGoBack;
    self.forwardButton.enabled = self.webView.canGoForward;
    if (!_isLoading) {
//        if (IS_IPAD) {
//            if (self.navigationController.navigationBarHidden == NO) {
//                self.title = [self getDocumentTitle];
//            } else {
//                [self.iPadNavBar.topItem setTitle:[self getDocumentTitle]];
//            }
//        } else {
            self.title = [self getDocumentTitle];
//        }
    }
}

- (NSString *)getDocumentPermalink
{
	NSString *permaLink = self.webView.URL.absoluteString;
	return permaLink;
	/*
	NSURLRequest *currentRequest = [self.webView request];
	if ( currentRequest != nil) {
		NSURL *currentURL = [currentRequest URL];
		permaLink = currentURL.absoluteString;
	}
	return permaLink;
	*/
	
	/*
    NSString *permaLink = [self.webView stringByEvaluatingJavaScriptFromString:@"Reader2.get_article_permalink();"];
    if ( permaLink == nil || [[permaLink trim] isEqualToString:@""]) {
        // try to get the loaded URL within the webView
        NSURLRequest *currentRequest = [self.webView request];
        if ( currentRequest != nil) {
            NSURL *currentURL = [currentRequest URL];
            permaLink = currentURL.absoluteString;
        }

        //make sure we are not sharing URL like this: http://en.wordpress.com/reader/mobile/?v=post-16841252-1828
        if ([permaLink rangeOfString:@"wordpress.com/reader/mobile/"].location != NSNotFound) {
            permaLink = WPMobileReaderURL;
        }
    }

    return permaLink;
	*/
}

- (NSString *)getDocumentDesc:(void(^)(NSString *))block
{
	// 返回之前就要截断不然可能会有内存出错
	NSString *js = @"\
	(function() {\
		function aaaa () {\
			try {\
				if (location.href.indexOf('lea.leanote.com') != -1) {\
					var metas = document.getElementsByTagName('meta');\
					for (i = 0; i < metas.length; i++) {\
						if (metas[i].getAttribute('name') == 'description') {\
							return metas[i].getAttribute('content');\
						}\
					}\
				}\
				var markdownElem = document.getElementById('markdownContent');\
				if (markdownElem) {\
					var textareaElem = markdownElem.getElementsByTagName('textarea');\
					if (textareaElem && textareaElem.length) return textareaElem[0].value;\
				}\
				var content = document.getElementById('content');\
				if (content) { return content.innerText.trim().substr(0, 50); }\
				var content = document.getElementsByClassName('content');\
				if (content && content.length) { return content[0].innerText; }\
				var desc = document.getElementsByClassName('desc');\
				if (desc && desc.length) { return desc[0].innerText; }\
				return document.getElementsByTagName('body')[0].innerText;\
				\
			} catch (e) { return ""; }\
		}\
		var content = aaaa();\
		return (content || '').trim().substr(0, 50);\
	})();\
	";
	//执行JS
	[self.webView evaluateJavaScript:js completionHandler:^(id _Nullable result, NSError * _Nullable error) {
		NSLog(@"get desc ret %@ %@", error, result);
		if (error == nil) {
			if (result != nil) {
				NSString *desc = [NSString stringWithFormat:@"%@", result];
				NSLog(@"desc %@", desc);
				// desc 多了, 不能调微信发送给朋友了
				if ( desc != nil && [[desc trim] isEqualToString:@""] == NO) {
					[desc stringByReplacingOccurrencesOfString:@"\n" withString:@""];
					if([desc length] > 50) {
						desc = [desc substringToIndex:47];
					}
					desc = [NSString stringWithFormat:@"%@...", desc];
					// return desc;
					block(desc);
				} else {
					block(@"...");
				}
			} else {
				block(@"...");
			}
		} else {
			NSLog(@"evaluateJavaScript error : %@", error.localizedDescription);
			block(@"...");
		}
	}];
}

- (NSString *)getDocumentTitle
{
	if (self.webView == nil) {
		NSLog(@"webview is nillllllllllll");
		return @"";
	}
	NSString *title = self.webView.title;
	
	if (title != nil && [[title trim] isEqualToString:@""] == NO) {
		return title;
	}
	
	return [self getDocumentPermalink] ?: [NSString string];
}

- (void)loadURL:(NSURL *)webURL
{
    // Subclass
}

- (void)refreshWebView
{
//    DDLogMethod()

    if (![ReachabilityUtils isInternetReachable]) {
        __weak LeaWebViewController *weakSelf = self;
        [ReachabilityUtils showAlertNoInternetConnectionWithRetryBlock:^{
            [weakSelf refreshWebView];
        }];

        self.optionsButton.enabled = NO;
        self.refreshButton.enabled = NO;
        return;
    }

	/*
    if (!self.needsLogin && self.username && self.password && ![WPCookie hasCookieForURL:self.url andUsername:self.username]) {
        DDLogWarn(@"We have login credentials but no cookie, let's try login first");
        [self retryWithLogin];
        return;
    }
	*/
    
    NSURLRequest *request = [self newRequestForWebsite];
    NSAssert(request, @"We should have a valid request here!");
    
    [self.webView loadRequest:request];
}

- (void)retryWithLogin
{
    self.needsLogin = YES;
    [self refreshWebView];
}

- (void)setUrl:(NSURL *)theURL
{
//    DDLogMethod()
    if (_url != theURL) {
        _url = theURL;
        if (_url && self.webView) {
            [self refreshWebView];
        }
    }
}

// refresh -> loading spin
- (void)setLoading:(BOOL)loading
{
    if (_isLoading == loading) {
        return;
    }

    self.optionsButton.enabled = !loading;

	/*
    if (IS_IPAD) {
        CGRect frame = self.loadingView.frame;
        if (loading) {
            frame.origin.y -= frame.size.height;
            [self.activityIndicator startAnimating];
        } else {
            frame.origin.y += frame.size.height;
            [self.activityIndicator stopAnimating];
        }

        [UIView animateWithDuration:0.2
                         animations:^{self.loadingView.frame = frame;}];
    }
	*/

    if (self.refreshButton) {
        self.refreshButton.enabled = !loading;
        // If on iPhone (or iPod Touch) swap between spinner and refresh button
//        if (IS_IPHONE) {
            // Build a spinner button if we don't have one
            if (self.spinnerButton == nil) {
                UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
                                                    initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
                UIView *customView = [[UIView alloc] initWithFrame:CGRectMake(10.0f, 0.0f, 32.0f, 32.0f)];
                [spinner setCenter:customView.center];

                [customView addSubview:spinner];
                [spinner startAnimating];

                self.spinnerButton = [[UIBarButtonItem alloc] initWithCustomView:customView];

            }
            NSMutableArray *newToolbarItems = [NSMutableArray arrayWithArray:self.toolbar.items];
            NSUInteger spinnerButtonIndex = [newToolbarItems indexOfObject:self.spinnerButton];
            NSUInteger refreshButtonIndex = [newToolbarItems indexOfObject:self.refreshButton];
            if (loading && refreshButtonIndex != NSNotFound) {
                [newToolbarItems replaceObjectAtIndex:refreshButtonIndex withObject:self.spinnerButton];
            } else if (spinnerButtonIndex != NSNotFound) {
                [newToolbarItems replaceObjectAtIndex:spinnerButtonIndex withObject:self.refreshButton];
            }
            self.toolbar.items = newToolbarItems;
//        }
    }
    _isLoading = loading;
}

- (void)dismiss
{
    [self.navigationController popViewControllerAnimated:NO];
}

// 后退
- (void)goBack
{
	[self.webView goBack];
	/*
    if (self.detailContent != nil) {
        NSString *prevItemAvailable = [self.webView evaluateJavaScript:@"Reader2.show_prev_item();"];
        if ( [prevItemAvailable rangeOfString:@"true"].location == NSNotFound ) {
            self.backButton.enabled = NO;
        } else {
            self.backButton.enabled = YES;
        }

        self.forwardButton.enabled = YES;

        if (IS_IPAD) {
            if (self.navigationController.navigationBarHidden == NO) {
                self.title = [self getDocumentTitle];
            } else {
                [self.iPadNavBar.topItem setTitle:[self getDocumentTitle]];
            }
        } else {
            self.title = [self getDocumentTitle];
        }
    } else {
        if ([self.webView isLoading]) {
            [self.webView stopLoading];
        }
        [self.webView goBack];
    }
	*/
}

// 前进
- (void)goForward
{
	[self.webView goForward];
	/*
    if (self.detailContent != nil) {
        NSString *nextItemAvailable = [self.webView evaluateJavaScript:@"Reader2.show_next_item();"  completionHandler:nil];
		
        if ([nextItemAvailable rangeOfString:@"true"].location == NSNotFound) {
            self.forwardButton.enabled = NO;
        } else {
            self.forwardButton.enabled = YES;
        }
        self.backButton.enabled = YES;
//        if (IS_IPAD) {
//            if (self.navigationController.navigationBarHidden == NO) {
//                self.title = [self getDocumentTitle];
//            } else {
//                [self.iPadNavBar.topItem setTitle:[self getDocumentTitle]];
//            }
//        } else {
            self.title = [self getDocumentTitle];
//        }
    } else {
        if ([self.webView isLoading]) {
            [self.webView stopLoading];
        }
        [self.webView goForward];
    }
	 */
}

- (void)showLinkOptions
{
    NSString* permaLink = [self getDocumentPermalink];

    NSString *title = [self getDocumentTitle];
	[self getDocumentDesc:^(NSString *desc){
		
		NSLog(@"showLinkOptions desc: %@", desc);
		
		NSMutableArray *activityItems = [NSMutableArray array];
		if (title) {
			[activityItems addObject:title];
		}
		if (desc) {
			[activityItems addObject:desc];
		}
		
		// weixin
		NSArray *activities = @[[[WeixinSessionActivity alloc] init], [[WeixinTimelineActivity alloc] init]];
		
		[activityItems addObject:[NSURL URLWithString:permaLink]];
		UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:activities];
		//	activityViewController.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypeCopyToPasteboard, UIActivityTypePrint];
		if (title) {
			[activityViewController setValue:title forKey:@"subject"];
		}
		activityViewController.completionHandler = ^(NSString *activityType, BOOL completed) {
			if (!completed) {
				return;
			}
			//        [WPActivityDefaults trackActivityType:activityType];
		};
		
		if (IS_IPAD) {
			if (self.popover) {
				[self dismissPopover];
				return;
			}
			self.popover = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
			self.popover.delegate = self;
			[self.popover presentPopoverFromBarButtonItem:self.optionsButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
		} else {
			[self presentViewController:activityViewController animated:YES completion:nil];
		}
	}];
}

- (void)reload
{
    if (![ReachabilityUtils isInternetReachable]) {
        __weak LeaWebViewController *weakSelf = self;
        [ReachabilityUtils showAlertNoInternetConnectionWithRetryBlock:^{
            [weakSelf refreshWebView];
        }];
        self.optionsButton.enabled = NO;
        self.refreshButton.enabled = NO;
        return;
    }
    [self setLoading:YES];
    [self.webView reload];
}

// Find the Webview's UIScrollView backwards compatible
- (UIScrollView *)scrollView
{
    UIScrollView *scrollView = nil;
    if ([self.webView respondsToSelector:@selector(scrollView)]) {
        scrollView = self.webView.scrollView;
    } else {
        for (UIView* subView in self.webView.subviews) {
            if ([subView isKindOfClass:[UIScrollView class]]) {
                scrollView = (UIScrollView*)subView;
            }
        }
    }
    return scrollView;
}

- (void)dismissPopover
{
    if (self.popover) {
        [self.popover dismissPopoverAnimated:YES];
        self.popover = nil;
    }
}

- (void)refreshInterface
{
	self.backButton.enabled = self.webView.canGoBack;
	self.forwardButton.enabled = self.webView.canGoForward;
	
	if (IS_IPAD) {
		if (self.navigationController.navigationBarHidden == NO) {
			self.title = [self getDocumentTitle];
		} else {
			[self.iPadNavBar.topItem setTitle:[self getDocumentTitle]];
		}
	} else {
		self.navigationItem.title = [self getDocumentTitle];
	}
	
	if ([self.webView.URL.absoluteString isEqualToString:@""]) {
		self.optionsButton.enabled = FALSE;
	} else {
		self.optionsButton.enabled = !self.webView.loading;
	}
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation{
	NSLog(@"didStartProvisionalNavigation!!!!......................");
	[self setLoading:YES];
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
	NSLog(@"didFinishNavigation!!!!!!!......................");
	[self setLoading:NO];
	[self refreshInterface];
	[webView evaluateJavaScript:@"var a = document.getElementsByTagName('a');for(var i=0;i<a.length;i++){a[i].setAttribute('target','');}" completionHandler:nil];
}
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
	NSLog(@"didFailNavigation!!!!......................");
	[self setLoading:NO];
	[self refreshInterface];
}

// _blank处理
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
	NSURLRequest *request = [navigationAction request];
	
	NSLog(@"%@ Should Start Loading [%@]", NSStringFromClass([self class]), request.URL.absoluteString);
	
	// To handle WhatsApp and Telegraph shares
	// Even though the documentation says that canOpenURL will only return YES for
	// URLs configured on the plist under LSApplicationQueriesSchemes if we don't filter
	// out http requests it also returns YES for those
	if (![request.URL.scheme hasPrefix:@"http"]
		&& [[UIApplication sharedApplication] canOpenURL:request.URL]) {
		[[UIApplication sharedApplication] openURL:request.URL
										   options:nil
								 completionHandler:nil];
		
		decisionHandler(WKNavigationActionPolicyCancel);
		return;
	}
	
	WKFrameInfo *frameInfo = navigationAction.targetFrame;
	if (![frameInfo isMainFrame]) {
		[webView loadRequest:navigationAction.request];
	}

//	if (self.navigationDelegate != nil) {
//		WebNavigationPolicy *policy = [self.navigationDelegate shouldNavigateWithRequest:request];
//
//		if (policy.redirectRequest != NULL) {
//			[self.webView loadRequest:policy.redirectRequest];
//			decisionHandler(WKNavigationActionPolicyCancel);
//			return;
//		}
//
//		decisionHandler(policy.action);
//		return;
//	}
	
	[self refreshInterface];
	
	decisionHandler(WKNavigationActionPolicyAllow);
}


#pragma mark - UIPopover Delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.popover = nil;
}

/*
#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request 
    navigationType:(UIWebViewNavigationType)navigationType
{
    DDLogInfo(@"%@ %@: %@", self, NSStringFromSelector(_cmd), [[request URL] absoluteString]);

    NSURL *requestedURL = [request URL];
    NSString *requestedURLAbsoluteString = [requestedURL absoluteString];

    if (![requestedURL isEqual:self.url] &&
        [requestedURLAbsoluteString rangeOfString:@"file://"].location == NSNotFound &&
        self.detailContent != nil &&
        navigationType == UIWebViewNavigationTypeLinkClicked
        ) {

        LeaWebViewController *webViewController = [[LeaWebViewController alloc] init];
        [webViewController setUrl:[request URL]];
        [self.navigationController pushViewController:webViewController animated:YES];
        return NO;
    }
	
	NSLog(@"reloading......................");

    [self setLoading:YES];
    return YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
//    DDLogInfo(@"%@ %@: %@", self, NSStringFromSelector(_cmd), error);
    // -999: Canceled AJAX request
    // 102:  Frame load interrupted: canceled wp-login redirect to make the POST
    if (self.isLoading && ([error code] != -999) && [error code] != 102) {
        [LeaAlert showAlertWithTitle:NSLocalizedString(@"Error", nil) message:error.localizedDescription];
    }
    [self setLoading:NO];
}

- (void)webViewDidStartLoad:(UIWebView *)aWebView
{
    DDLogInfo(@"%@ %@%@", self, NSStringFromSelector(_cmd), aWebView.request.URL);
}

// 页面加载结束时调用
- (void)webViewDidFinishLoad:(UIWebView *)aWebView
{
//    DDLogMethod()
    [self setLoading:NO];

    CGSize webviewSize = self.view.frame.size;
 
    // NSString *js = [NSString stringWithFormat:@"var meta = document.createElement('meta');meta.setAttribute( 'name', 'viewport' ); meta.setAttribute( 'content', 'width = %d, initial-scale = 1.0, user-scalable = yes' );document.getElementsByTagName('head')[0].appendChild(meta)", webviewSize.width];
    // [aWebView stringByEvaluatingJavaScriptFromString: js];

 
 // &&
 ([aWebView.request.URL.absoluteString rangeOfString:WPMobileReaderDetailURL].location == NSNotFound || self.detailContent)
    if (!self.hasLoadedContent) {
        [aWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"Reader2.set_loaded_items(%@);", self.readerAllItems]];
        [aWebView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"Reader2.show_article_details(%@);", self.detailContent]];

        if (IS_IPAD) {
            if (self.navigationController.navigationBarHidden == NO) {
                self.title = [self getDocumentTitle];
            } else {
                [self.iPadNavBar.topItem setTitle:[self getDocumentTitle]];
            }
        } else {
            self.navigationItem.title = [self getDocumentTitle];
        }

        NSString *prevItemAvailable = [aWebView stringByEvaluatingJavaScriptFromString:@"Reader2.is_prev_item();"];
        if ([prevItemAvailable rangeOfString:@"true"].location == NSNotFound) {
            self.backButton.enabled = NO;
        } else {
            self.backButton.enabled = YES;
        }

        NSString *nextItemAvailable = [aWebView stringByEvaluatingJavaScriptFromString:@"Reader2.is_next_item();"];
        if ([nextItemAvailable rangeOfString:@"true"].location == NSNotFound) {
            self.forwardButton.enabled = NO;
        } else {
            self.forwardButton.enabled = YES;
        }

        self.hasLoadedContent = YES;
    }
    if (self.shouldScrollToBottom == YES) {
        self.shouldScrollToBottom = NO;
        CGPoint bottomOffset = CGPointMake(0, self.scrollView.contentSize.height - self.scrollView.bounds.size.height);
        [self.scrollView setContentOffset:bottomOffset animated:YES];
    }
	
	// 当加载完后才登录
	
	// 总是重新登录
	// 需要登录
	if(self.needsLogin) {
//		NSLog(@"needsLogin");
		self.needsLogin = NO;
		[self loginLeanote:self.host email:self.email pwd:self.pwd];
	}
}

*/


#pragma mark - Requests Helpers

- (NSURLRequest *)newRequestForWebsite
{
	return [LeaURLRequest requestWithURL:self.url userAgent:nil];
	
	/*
    NSString *userAgent = [[WordPressAppDelegate sharedInstance].userAgent currentUserAgent];
    if (!self.needsLogin) {
		
    }
    
    NSURL *loginURL = self.wpLoginURL ?: [[NSURL alloc] initWithScheme:self.url.scheme host:self.url.host path:@"/wp-login.php"];
    
    return [LeaURLRequest requestForAuthenticationWithURL:loginURL
                                             redirectURL:self.url
                                                username:self.username
                                                password:self.password
                                             bearerToken:self.authToken
                                               userAgent:userAgent];
	*/
}

// login
- (void) loginLeanote:(NSString *) host email:(NSString *) email pwd:(NSString *) pwd
{
	if([host hasPrefix:@"http://leanote.com"]) {
		host = @"https://leanote.com"; // 用SSL
	}
	NSString *loginJs = [NSString stringWithFormat:@"\
	(function(host, email, pwd) { \
		/* 创建iframe*/ \
		var iframe = document.createElement(\"IFRAME\"); \
		var iframeName = '_IFrame_LEANOTE_IOS_'; \
		iframe.style.cssText = 'border: 0px transparent; width: 0; height: 0;'; \
		iframe.setAttribute('name', iframeName); \
		iframe.setAttribute('id', iframeName); \
		document.documentElement.appendChild(iframe); \
		\
		/* 创建表单 */ \
		var f = document.createElement(\"form\"); \
		f.style.cssText = 'border: 0px transparent; width: 0; height: 0;'; \
		document.body.appendChild(f); \
		var e = document.createElement(\"input\"); \
		e.type = \"hidden\"; e.name = \"email\"; e.value = email;  \
		f.appendChild(e); \
		var p = document.createElement(\"input\"); \
		p.type = \"hidden\"; p.name = \"pwd\"; p.value = pwd; \
		f.appendChild(p); \
		\
		f.action = host + \"/auth/doLogin\"; \
		f.method = \"POST\"; \
		f.target = iframeName; \
		f.submit(); \
	})('%@', '%@', '%@');", host, email, pwd];
//	NSLog(@"%@", loginJs);
	[self.webView evaluateJavaScript:loginJs completionHandler:nil];
}

@end
