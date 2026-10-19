#import <UIKit/UIKit.h>

#define L16_DOMAIN CFSTR("com.michaelmelita1.little16")
#define L16_RELOAD "com.michaelmelita1.little16/reload"

static NSDictionary *prefs;
static BOOL advanced;

static void LoadPrefs(void) {
    CFPreferencesAppSynchronize(L16_DOMAIN);
    NSDictionary *d = nil;
    CFArrayRef keys = CFPreferencesCopyKeyList(L16_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keys) {
        d = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keys, L16_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFRelease(keys);
    }
    prefs = d ?: @{};
    advanced = [prefs[@"advancedMode"] boolValue];
}

static BOOL PrefBool(NSString *key, BOOL def) {
    id v = prefs[key];
    return v ? [v boolValue] : def;
}

static double PrefNum(NSString *key, double def) {
    id v = prefs[key];
    if ([v isKindOfClass:[NSString class]]) {
        NSString *s = [v stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        return s.length ? s.doubleValue : def;
    }
    return [v isKindOfClass:[NSNumber class]] ? [v doubleValue] : def;
}

static double SimpleHeight(void) { return PrefNum(@"s_barHeight", 24); }
static double SimpleOffset(void) { return PrefNum(@"s_barOffset", 6); }
static double SimpleMargin(void) { return PrefNum(@"s_sideMargin", 22); }

static BOOL ClockLeft(void) { return PrefBool(@"clockLeftAligned", NO); }

static double AppPadding(void) { return advanced ? PrefNum(@"a_appPadding", 24) : SimpleHeight(); }
static double EditorPadding(void) { return advanced ? PrefNum(@"a_editorPadding", 24) : SimpleHeight(); }
static double TimeTop(void) { return advanced ? PrefNum(@"a_timeTop", 7) : SimpleOffset() + 1; }
static double TimeInset(void) { return advanced ? PrefNum(@"a_timeInset", ClockLeft() ? 22 : 14) : (ClockLeft() ? SimpleMargin() : SimpleMargin() - 8); }
static double IconsTop(void) { return advanced ? PrefNum(@"a_iconsTop", 6) : SimpleOffset(); }
static double IconsInset(void) { return advanced ? PrefNum(@"a_iconsInset", 22) : SimpleMargin(); }
static double AdvNum(NSString *key, double def) { return advanced ? PrefNum(key, def) : def; }

static NSString *ProviderName(void) {
    NSString *m = advanced ? prefs[@"a_statusBarModel"] : nil;
    return [m isKindOfClass:[NSString class]] && m.length ? m : @"Split1125";
}

%group Core

@interface NCNotificationListView : UIView
@end

%hook NCNotificationListView
- (void)setFrame:(CGRect)frame {
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){16, 0, 0}]) {
        frame = CGRectMake(0, AdvNum(@"a_notifListY", -100), frame.size.width, frame.size.height);
    }
    %orig(frame);
}
%end

@interface CSFullscreenNotificationView : UIView
@end

%hook CSFullscreenNotificationView
- (void)setFrame:(CGRect)frame {
    frame = CGRectMake(0, AdvNum(@"a_fullscreenNotifY", -50), frame.size.width, frame.size.height);
    %orig(frame);
}
%end

%hook SBHomeGestureSettings
- (bool)isHomeGestureEnabled {
    return 1;
}
%end

%end

%group QuickActions

static BOOL ViewContainsClass(UIView *view, Class targetClass, int depth) {
    if (!view || depth > 20) return NO;
    if ([view isKindOfClass:targetClass]) return YES;
    for (UIView *sub in view.subviews) {
        if (ViewContainsClass(sub, targetClass, depth + 1)) return YES;
    }
    return NO;
}

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets orig = %orig;
    if (orig.bottom <= 0.0) {
        Class qaCls = NSClassFromString(@"CSQuickActionsButton");
        if (qaCls && ViewContainsClass(self, qaCls, 0)) {
            orig.bottom = AdvNum(@"a_lockBottomInset", 20);
        }
    }
    return orig;
}
%end

@interface CSQuickActionsView : UIView
- (UIEdgeInsets)_buttonOutsets;
@property (nonatomic, retain) UIControl *flashlightButton;
@property (nonatomic, retain) UIControl *cameraButton;
@end

%hook CSQuickActionsView

- (BOOL)wantsQuickActions {
    return YES;
}

- (BOOL)_prototypingAllowsButtons {
    return YES;
}

- (void)_layoutQuickActionButtons {
    CGRect const screenBounds = [UIScreen mainScreen].bounds;
    CGFloat const inset = AdvNum(@"a_qaSideInset", 46);
    CGFloat const size = AdvNum(@"a_qaSize", 50);
    CGFloat const y = screenBounds.size.height - AdvNum(@"a_qaBottom", 90) - [self _buttonOutsets].top;
    [self flashlightButton].frame = CGRectMake(inset, y, size, size);
    [self cameraButton].frame = CGRectMake(screenBounds.size.width - inset - size, y, size, size);
}

%end

%hook CSQuickActionsViewController
+ (BOOL)deviceSupportsButtons {
    return YES;
}
- (BOOL)hasCamera { return YES; }
- (BOOL)hasFlashlight { return YES; }
%end

%end

%group ControlCenter

%hook CCSControlCenterDefaults
- (unsigned long long)_defaultPresentationGesture {
    return 1;
}
%end

%hook SBControlCenterController
- (unsigned long long)presentingEdge {
    return 1;
}
%end

%end

%group HomeBar

%hook SBFHomeGrabberSettings
-(BOOL)isEnabled {
	return NO;
}

-(void)setEnabled:(BOOL)arg1 {
	%orig(NO);
}
%end

%end

%group StatusBar

%hook _UIStatusBarVisualProvider_iOS
+ (Class)class {
    return NSClassFromString([@"_UIStatusBarVisualProvider_" stringByAppendingString:ProviderName()]) ?: %orig;
}
%end

%hook _UIStatusBarVisualProvider_Split
- (NSDirectionalEdgeInsets)leadingEdgeInsets {
    NSDirectionalEdgeInsets r = %orig;
    CGFloat const inset = TimeInset();
    r.top += TimeTop();
    r.trailing -= inset - r.leading;
    r.leading = inset;
    return r;
}
- (NSDirectionalEdgeInsets)trailingEdgeInsets {
    NSDirectionalEdgeInsets r = %orig;
    CGFloat const inset = IconsInset();
    r.top += IconsTop();
    r.leading -= inset - r.trailing;
    r.trailing = inset;
    return r;
}
%end

%hook L16Provider
+ (double)height {
    return AppPadding();
}
%end

%end

%group ClockLeft

@interface _UIStatusBarRegionAxisCenteringLayout : NSObject
@property (nonatomic) double interspace;
@end

@interface _UIStatusBarRegionAxisStackingLayout : NSObject
@property (nonatomic) long long alignment;
@property (nonatomic) double interspace;
@end

@interface _UIStatusBarRegionAxesLayout : NSObject
@property (nonatomic, retain) id horizontalLayout;
@end

@interface _UIStatusBarRegion : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, retain) id layout;
@end

%hook _UIStatusBarVisualProvider_Split
- (NSArray *)setupInContainerView:(id)view {
    NSArray *regions = %orig;
    for (_UIStatusBarRegion *region in regions) {
        if (![region isKindOfClass:%c(_UIStatusBarRegion)] || ![region.identifier isEqualToString:@"leading"]) continue;
        _UIStatusBarRegionAxesLayout *layout = region.layout;
        if (![layout isKindOfClass:%c(_UIStatusBarRegionAxesLayout)]) continue;
        _UIStatusBarRegionAxisCenteringLayout *old = layout.horizontalLayout;
        _UIStatusBarRegionAxisStackingLayout *stack = [[%c(_UIStatusBarRegionAxisStackingLayout) alloc] init];
        stack.alignment = 3;
        if ([old respondsToSelector:@selector(interspace)]) stack.interspace = old.interspace;
        layout.horizontalLayout = stack;
    }
    return regions;
}
%end

%end

%group ScreenshotEditor

%hook UIWindow
- (UIEdgeInsets)safeAreaInsets {
    UIEdgeInsets r = %orig;
    CGFloat const top = EditorPadding();
    if (r.top < top) r.top = top;
    return r;
}
%end

%end

static void PrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    LoadPrefs();
}

%ctor {
    LoadPrefs();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PrefsChanged, CFSTR(L16_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    if (!PrefBool(@"enabled", YES)) return;

    BOOL const statusBar = PrefBool(@"statusBar", YES);
    if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        if (statusBar) %init(ScreenshotEditor);
        return;
    }

    %init(Core);
    if (PrefBool(@"quickActions", YES)) %init(QuickActions);
    if (PrefBool(@"controlCenterTopRight", YES)) %init(ControlCenter);
    if (PrefBool(@"hideHomeBar", YES)) %init(HomeBar);
    if (statusBar) {
        Class provider = NSClassFromString([@"_UIStatusBarVisualProvider_" stringByAppendingString:ProviderName()]);
        if (provider) {
            %init(StatusBar, L16Provider = provider);
            if (PrefBool(@"clockLeftAligned", NO)) %init(ClockLeft);
        }
    }
}
