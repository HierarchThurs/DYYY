#import "DYYYDebugFloatButton.h"

static NSString *const kDYYYDebugButtonCenterXPercentKey = @"DYYYDebugButtonCenterXPercent";
static NSString *const kDYYYDebugButtonCenterYPercentKey = @"DYYYDebugButtonCenterYPercent";

NSInteger const DYYYDebugFloatButtonTag = 931031;

@interface DYYYDebugFloatButton () <UIGestureRecognizerDelegate>

@property(nonatomic, assign) CGPoint lastLocation;

@end

@implementation DYYYDebugFloatButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.tag = DYYYDebugFloatButtonTag;
    self.accessibilityLabel = @"DYYYDebugFloatButton";
    self.backgroundColor = [UIColor colorWithRed:0.94 green:0.39 blue:0.18 alpha:0.92];
    self.layer.cornerRadius = CGRectGetWidth(frame) / 2.0;
    self.layer.masksToBounds = YES;
    self.layer.borderWidth = 1.0;
    self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.35].CGColor;
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.18;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = 8.0;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    [self setTitle:@"调试" forState:UIControlStateNormal];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    panGesture.delegate = self;
    [self addGestureRecognizer:panGesture];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = CGRectGetWidth(self.bounds) / 2.0;
}

- (void)didMoveToSuperview {
    [super didMoveToSuperview];
    if (self.superview) {
        [self loadSavedPosition];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return [gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (!self.superview) {
        return;
    }

    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    CGFloat halfWidth = CGRectGetWidth(self.bounds) / 2.0;
    CGFloat halfHeight = CGRectGetHeight(self.bounds) / 2.0;
    CGRect bounds = self.superview.bounds;

    newCenter.x = MAX(halfWidth, MIN(newCenter.x, CGRectGetWidth(bounds) - halfWidth));
    newCenter.y = MAX(halfHeight, MIN(newCenter.y, CGRectGetHeight(bounds) - halfHeight));
    self.center = newCenter;
    [gesture setTranslation:CGPointZero inView:self.superview];

    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [self saveButtonPosition];
    }
}

- (void)saveButtonPosition {
    if (!self.superview) {
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat width = CGRectGetWidth(self.superview.bounds);
    CGFloat height = CGRectGetHeight(self.superview.bounds);
    if (width <= 0.0 || height <= 0.0) {
        return;
    }

    [defaults setFloat:self.center.x / width forKey:kDYYYDebugButtonCenterXPercentKey];
    [defaults setFloat:self.center.y / height forKey:kDYYYDebugButtonCenterYPercentKey];
}

- (void)loadSavedPosition {
    if (!self.superview) {
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat centerXPercent = [defaults floatForKey:kDYYYDebugButtonCenterXPercentKey];
    CGFloat centerYPercent = [defaults floatForKey:kDYYYDebugButtonCenterYPercentKey];
    CGRect bounds = self.superview.bounds;
    CGFloat width = CGRectGetWidth(bounds);
    CGFloat height = CGRectGetHeight(bounds);
    CGFloat halfWidth = CGRectGetWidth(self.bounds) / 2.0;
    CGFloat halfHeight = CGRectGetHeight(self.bounds) / 2.0;

    CGPoint center = CGPointZero;
    if (centerXPercent > 0.0 && centerYPercent > 0.0) {
        center = CGPointMake(centerXPercent * width, centerYPercent * height);
    } else {
        CGFloat safeTop = 0.0;
        if (@available(iOS 11.0, *)) {
            safeTop = self.superview.safeAreaInsets.top;
        }
        center = CGPointMake(width - halfWidth - 12.0, safeTop + halfHeight + 72.0);
    }

    center.x = MAX(halfWidth, MIN(center.x, width - halfWidth));
    center.y = MAX(halfHeight, MIN(center.y, height - halfHeight));
    self.center = center;
}

@end
