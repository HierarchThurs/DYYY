#import "DYYYDebugMenuViewController.h"

#import <objc/runtime.h>

#import "AwemeHeaders.h"

@interface DYYYDebugMenuViewController ()

@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIStackView *stackView;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *messageLabel;
@property(nonatomic, strong) UIButton *closeButton;
@property(nonatomic, assign) BOOL didNotifyClose;

@end

@implementation DYYYDebugMenuAction

+ (instancetype)actionWithTitle:(NSString *)title detail:(NSString *)detail handler:(dispatch_block_t)handler {
    DYYYDebugMenuAction *action = [[self alloc] init];
    action.title = title ?: @"";
    action.detail = detail;
    action.handler = handler ?: ^{};
    return action;
}

@end

@implementation DYYYDebugMenuViewController

+ (UIViewController *)showWithTitle:(NSString *)title
                            message:(NSString *)message
                            actions:(NSArray<DYYYDebugMenuAction *> *)actions
           onPresentingViewController:(UIViewController *)presentingViewController
                         closeAction:(dispatch_block_t)closeAction {
    if (!presentingViewController) {
        return nil;
    }

    DYYYDebugMenuViewController *rootViewController = [[self alloc] init];
    rootViewController.menuTitleText = title ?: @"调试导出";
    rootViewController.menuMessageText = message;
    rootViewController.actions = actions ?: @[];
    rootViewController.onClose = closeAction;

    DUXContentSheet *contentSheet = [[NSClassFromString(@"DUXContentSheet") alloc] initWithRootViewController:rootViewController withTopType:0 withSheetAligment:0];
    [contentSheet setAutoAlignmentCenter:YES];
    [contentSheet setSheetCornerRadius:14.0];
    [contentSheet showOnViewController:presentingViewController completion:nil];
    return contentSheet;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self buildInterface];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self notifyCloseIfNeeded];
}

#pragma mark - UI

- (void)buildInterface {
    UIScrollView *scrollView = [[UIScrollView alloc] init];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView = scrollView;

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 12.0;
    self.stackView = stackView;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.numberOfLines = 0;
    titleLabel.text = self.menuTitleText ?: @"调试导出";
    self.titleLabel = titleLabel;

    UILabel *messageLabel = [[UILabel alloc] init];
    messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    messageLabel.font = [UIFont systemFontOfSize:13.0];
    messageLabel.textColor = [UIColor secondaryLabelColor];
    messageLabel.numberOfLines = 0;
    messageLabel.text = self.menuMessageText ?: @"";
    self.messageLabel = messageLabel;

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    closeButton.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(handleCloseTapped) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton = closeButton;

    UIView *headerContainer = [[UIView alloc] init];
    headerContainer.translatesAutoresizingMaskIntoConstraints = NO;

    [headerContainer addSubview:titleLabel];
    [headerContainer addSubview:messageLabel];
    [headerContainer addSubview:closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [closeButton.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
        [closeButton.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
        [closeButton.widthAnchor constraintGreaterThanOrEqualToConstant:44.0],
        [closeButton.heightAnchor constraintEqualToConstant:32.0],

        [titleLabel.topAnchor constraintEqualToAnchor:headerContainer.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:closeButton.leadingAnchor constant:-12.0],

        [messageLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [messageLabel.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor],
        [messageLabel.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor],
        [messageLabel.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor],
    ]];

    [stackView addArrangedSubview:headerContainer];
    for (DYYYDebugMenuAction *action in self.actions) {
        [stackView addArrangedSubview:[self actionButtonForAction:action]];
    }

    [scrollView addSubview:stackView];
    [self.view addSubview:scrollView];

    UILayoutGuide *safeArea = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:safeArea.topAnchor constant:18.0],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20.0],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20.0],
        [scrollView.bottomAnchor constraintEqualToAnchor:safeArea.bottomAnchor constant:-18.0],

        [stackView.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor],
        [stackView.leadingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.leadingAnchor],
        [stackView.trailingAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.trailingAnchor],
        [stackView.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor],
        [stackView.widthAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.widthAnchor],
    ]];
}

- (UIView *)actionButtonForAction:(DYYYDebugMenuAction *)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = [UIColor secondarySystemBackgroundColor];
    button.layer.cornerRadius = 12.0;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(14.0, 14.0, 14.0, 14.0);
    [button addTarget:self action:@selector(handleActionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(button, @selector(handleActionButtonTapped:), action, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = [UIColor labelColor];
    titleLabel.numberOfLines = 0;
    titleLabel.text = action.title ?: @"";

    UILabel *detailLabel = [[UILabel alloc] init];
    detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    detailLabel.font = [UIFont systemFontOfSize:12.0];
    detailLabel.textColor = [UIColor secondaryLabelColor];
    detailLabel.numberOfLines = 0;
    detailLabel.text = action.detail ?: @"";
    detailLabel.hidden = action.detail.length == 0;

    [button addSubview:titleLabel];
    [button addSubview:detailLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:button.topAnchor constant:14.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:button.leadingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:button.trailingAnchor constant:-14.0],

        [detailLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:6.0],
        [detailLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [detailLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [detailLabel.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-14.0],
    ]];

    NSLayoutConstraint *compactBottomConstraint = [titleLabel.bottomAnchor constraintEqualToAnchor:button.bottomAnchor constant:-14.0];
    compactBottomConstraint.active = (action.detail.length == 0);
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:(action.detail.length > 0 ? 74.0 : 52.0)].active = YES;

    return button;
}

#pragma mark - Actions

- (void)handleActionButtonTapped:(UIButton *)sender {
    DYYYDebugMenuAction *action = objc_getAssociatedObject(sender, @selector(handleActionButtonTapped:));
    if (!action.handler) {
        return;
    }

    dispatch_block_t handler = [action.handler copy];
    UIViewController *dismissTarget = self.parentViewController ?: self.presentingViewController;
    if (dismissTarget) {
        [dismissTarget dismissViewControllerAnimated:YES completion:^{
          handler();
        }];
        return;
    }

    [self notifyCloseIfNeeded];
    handler();
}

- (void)handleCloseTapped {
    UIViewController *dismissTarget = self.parentViewController ?: self.presentingViewController ?: self;
    [dismissTarget dismissViewControllerAnimated:YES completion:nil];
}

- (void)notifyCloseIfNeeded {
    if (self.didNotifyClose) {
        return;
    }
    self.didNotifyClose = YES;
    if (self.onClose) {
        self.onClose();
    }
}

@end
