#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSSliderTableCell.h>
#import <Preferences/PSEditableTableCell.h>
#include <spawn.h>

#define L16_DOMAIN CFSTR("com.michaelmelita1.little16")
#define L16_RELOAD CFSTR("com.michaelmelita1.little16/reload")

@interface L16RootListController : PSListController
@end

@interface PSSpecifier (L16)
- (void)setValues:(NSArray *)values titles:(NSArray *)titles;
@end

@interface L16EditCell : PSEditableTableCell
@end

@implementation L16EditCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(l16_pressed:)];
        press.cancelsTouchesInView = NO;
        [self addGestureRecognizer:press];
    }
    return self;
}

- (BOOL)l16_isEditingText:(UIView *)view {
    if ([view isKindOfClass:[UITextField class]] && view.isFirstResponder) return YES;
    for (UIView *sub in view.subviews) {
        if ([self l16_isEditingText:sub]) return YES;
    }
    return NO;
}

- (void)l16_pressed:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan || [self l16_isEditingText:self]) return;
    PSListController *controller = self.specifier.target;
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    [controller setPreferenceValue:[self.specifier propertyForKey:@"placeholder"] specifier:self.specifier];
    [controller reloadSpecifier:self.specifier animated:NO];
}

@end

@interface L16SliderCell : PSSliderTableCell
@end

@implementation L16SliderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(l16_tapped:)];
        tap.cancelsTouchesInView = NO;
        [self.contentView addGestureRecognizer:tap];
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(l16_pressed:)];
        press.cancelsTouchesInView = NO;
        [self.contentView addGestureRecognizer:press];
    }
    return self;
}

- (BOOL)l16_touchOnThumb:(UIGestureRecognizer *)g {
    if (![self.control isKindOfClass:[UISlider class]]) return NO;
    UISlider *slider = (UISlider *)self.control;
    CGRect track = [slider trackRectForBounds:slider.bounds];
    CGRect thumb = CGRectInset([slider thumbRectForBounds:slider.bounds trackRect:track value:slider.value], -10, -10);
    return CGRectContainsPoint(thumb, [g locationInView:slider]);
}

- (void)l16_apply:(id)value {
    PSListController *controller = self.specifier.target;
    [controller setPreferenceValue:value specifier:self.specifier];
    [controller reloadSpecifier:self.specifier animated:NO];
}

- (void)l16_tapped:(UITapGestureRecognizer *)g {
    if ([self l16_touchOnThumb:g]) return;
    PSSpecifier *spec = self.specifier;
    PSListController *controller = spec.target;
    double const min = [[spec propertyForKey:@"min"] doubleValue];
    double const max = [[spec propertyForKey:@"max"] doubleValue];
    double const current = [[controller readPreferenceValue:spec] doubleValue];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Enter Value" message:[NSString stringWithFormat:@"%g to %g", min, max] preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.keyboardType = UIKeyboardTypeDecimalPad;
        field.text = [NSString stringWithFormat:@"%g", current];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Set" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        if (!text.length) return;
        [self l16_apply:@(MIN(MAX(text.doubleValue, min), max))];
    }]];
    [controller presentViewController:alert animated:YES completion:nil];
}

- (void)l16_pressed:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan || [self l16_touchOnThumb:g]) return;
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
    [self l16_apply:nil];
}

@end

@interface L16HelpPageController : PSListController
@end

@implementation L16HelpPageController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.specifier.name;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    for (NSArray *entry in [self.specifier propertyForKey:@"l16Sections"]) {
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:entry[0]];
        [group setProperty:entry[1] forKey:@"footerText"];
        [s addObject:group];
    }
    _specifiers = s;
    return _specifiers;
}

@end

@interface L16HelpController : PSListController
@end

@implementation L16HelpController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Help";
}

- (PSSpecifier *)page:(NSString *)name sections:(NSArray *)sections {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:name target:self set:nil get:nil detail:[L16HelpPageController class] cell:PSLinkCell edit:nil];
    [s setProperty:sections forKey:@"l16Sections"];
    return s;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    _specifiers = [@[
        [PSSpecifier groupSpecifierWithName:nil],
        [self page:@"Features" sections:@[
            @[@"Enabled", @"Turns the whole tweak on or off. The iPhone X home gesture is always on while Little16 is enabled. Applies after a respring."],
            @[@"iPhone X Status Bar", @"Replaces the stock status bar with the notched iPhone layout: clock on the left, signal, Wi-Fi and battery on the right. It also pads the screenshot editor so its toolbar sits below the status bar. Applies after a respring."],
            @[@"Left-Aligned Clock", @"The notched layout centres the clock in its area, so times of different widths (like 9:41 and 05:42) sit at slightly different spots. This pins the clock to a fixed distance from the left edge instead. Applies after a respring."],
            @[@"Lock Screen Flashlight & Camera", @"Adds the flashlight and camera buttons to the bottom of the lock screen. Applies after a respring."],
            @[@"Control Center From Top Right", @"Opens Control Center by swiping down from the top-right corner, like on notched iPhones, instead of swiping up. Applies after a respring."],
            @[@"Hide Home Bar", @"Hides the home indicator line at the bottom of the screen. Applies after a respring."],
        ]],
        [self page:@"Simple" sections:@[
            @[@"How Simple Mode Works", @"Three sliders cover the status bar. Tap a slider anywhere except its knob to type an exact value, or long press it to reset to the default. Your simple values are kept when you switch to advanced mode and come back when you switch back."],
            @[@"App Top Padding", @"How much space apps leave at the top for the status bar, in points. Too small and app content runs under the status bar; too big and there's a gap between the status bar and the app. The screenshot editor uses the same value. Default 24."],
            @[@"Status Bar Vertical Offset", @"How far the clock and icons are pushed down from where the notched layout would put them. Default 6."],
            @[@"Side Margin", @"Distance between the battery side and the right edge of the screen. The clock is matched to it on the left, taking Left-Aligned Clock into account. Default 22."],
        ]],
        [self page:@"Advanced" sections:@[
            @[@"How Advanced Mode Works", @"Every value can be set on its own, and these values are kept separately from simple mode. Turning advanced mode on fills any empty fields with what your simple sliders currently give. An empty field silently uses the tweak's default, and long pressing a field resets it to the default. Copy Simple Values to Advanced overwrites the status bar fields with your current simple values."],
            @[@"Model", @"Which notched iPhone's status bar layout to borrow. Each has slightly different spacing and font sizes, so you may need to retune the other values after switching. Applies after a respring."],
            @[@"App Top Padding", @"Space apps leave at the top for the status bar, in points. Default 24."],
            @[@"Screenshot Editor Padding", @"Space the screenshot editor leaves at the top, so its toolbar sits below the status bar. Default 24."],
            @[@"Clock: Top Offset", @"Pushes the clock down, added on top of the layout's own spacing. Default 7."],
            @[@"Clock: Edge Inset", @"Distance of the clock's area from the left edge. Without Left-Aligned Clock the clock is centred in that area, so it appears about 8 points further in than this value. Default 14, or 22 with Left-Aligned Clock."],
            @[@"Battery Side: Top Offset", @"Pushes the signal, Wi-Fi and battery icons down. Default 6."],
            @[@"Battery Side: Edge Inset", @"Distance of the battery side from the right edge. Default 22."],
            @[@"Lock Screen Buttons", @"Side Inset is the distance of the flashlight and camera buttons from the screen edges (default 46). Bottom Offset is how far up from the bottom they sit (default 90). Size is their width and height (default 50)."],
            @[@"Bottom Safe Area", @"Space the lock screen keeps free at the bottom while the buttons are shown, so other content doesn't overlap them. Default 20."],
            @[@"Notification Positions", @"Fullscreen Notification Y moves the lock screen's fullscreen notification view up or down (default -50). Notification List Y moves the notification list and only applies on iOS 16 (default -100)."],
        ]],
    ] mutableCopy];
    return _specifiers;
}

@end

@implementation L16RootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Little16";
}

- (id)storedValue:(NSString *)key {
    return (__bridge_transfer id)CFPreferencesCopyAppValue((__bridge CFStringRef)key, L16_DOMAIN);
}

- (double)storedNum:(NSString *)key def:(double)def {
    id v = [self storedValue:key];
    if ([v isKindOfClass:[NSString class]]) return [v length] ? [v doubleValue] : def;
    return [v isKindOfClass:[NSNumber class]] ? [v doubleValue] : def;
}

- (void)store:(id)value key:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, L16_DOMAIN);
    CFPreferencesAppSynchronize(L16_DOMAIN);
}

- (void)notifyTweak {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), L16_RELOAD, NULL, NULL, YES);
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    return [self storedValue:[specifier propertyForKey:@"key"]] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([value isKindOfClass:[NSString class]] && ![value length]) value = nil;
    [self store:value key:key];
    [self notifyTweak];
    if ([key isEqualToString:@"advancedMode"]) {
        if ([value boolValue]) [self seedAdvanced];
        [self reloadSpecifiers];
    }
}

- (NSDictionary *)advancedDefaults {
    return @{
        @"a_appPadding": @24,
        @"a_editorPadding": @24,
        @"a_timeTop": @7,
        @"a_timeInset": [[self storedValue:@"clockLeftAligned"] boolValue] ? @22 : @14,
        @"a_iconsTop": @6,
        @"a_iconsInset": @22,
        @"a_qaSideInset": @46,
        @"a_qaBottom": @90,
        @"a_qaSize": @50,
        @"a_lockBottomInset": @20,
        @"a_fullscreenNotifY": @-50,
        @"a_notifListY": @-100,
    };
}

- (void)seedAdvanced {
    NSDictionary *derived = [self simpleDerived];
    [[self advancedDefaults] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *def, BOOL *stop) {
        id stored = [self storedValue:key];
        if ([stored isKindOfClass:[NSNumber class]] || ([stored isKindOfClass:[NSString class]] && [stored length])) return;
        NSNumber *value = derived[key] ?: def;
        [self store:[NSString stringWithFormat:@"%g", value.doubleValue] key:key];
    }];
    [self notifyTweak];
}

- (NSDictionary *)simpleDerived {
    double const height = [self storedNum:@"s_barHeight" def:24];
    double const offset = [self storedNum:@"s_barOffset" def:6];
    double const margin = [self storedNum:@"s_sideMargin" def:22];
    return @{
        @"a_appPadding": @(height),
        @"a_editorPadding": @(height),
        @"a_timeTop": @(offset + 1),
        @"a_timeInset": @([[self storedValue:@"clockLeftAligned"] boolValue] ? margin : margin - 8),
        @"a_iconsTop": @(offset),
        @"a_iconsInset": @(margin),
    };
}

- (PSSpecifier *)group:(NSString *)name footer:(NSString *)footer {
    PSSpecifier *s = [PSSpecifier groupSpecifierWithName:name];
    if (footer) [s setProperty:footer forKey:@"footerText"];
    return s;
}

- (PSSpecifier *)cell:(PSCellType)type name:(NSString *)name key:(NSString *)key def:(id)def {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:name target:self set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:type edit:nil];
    [s setProperty:key forKey:@"key"];
    if (def) [s setProperty:def forKey:@"default"];
    return s;
}

- (PSSpecifier *)toggle:(NSString *)name key:(NSString *)key def:(BOOL)def {
    return [self cell:PSSwitchCell name:name key:key def:@(def)];
}

- (PSSpecifier *)slider:(NSString *)key def:(double)def min:(double)min max:(double)max {
    PSSpecifier *s = [self cell:PSSliderCell name:nil key:key def:@(def)];
    [s setProperty:@(min) forKey:@"min"];
    [s setProperty:@(max) forKey:@"max"];
    [s setProperty:@YES forKey:@"showValue"];
    [s setProperty:@YES forKey:@"isSegmented"];
    [s setProperty:@(max - min) forKey:@"segmentCount"];
    [s setProperty:[L16SliderCell class] forKey:@"cellClass"];
    return s;
}

- (PSSpecifier *)number:(NSString *)name key:(NSString *)key {
    PSSpecifier *s = [self cell:PSEditTextCell name:name key:key def:nil];
    [s setProperty:[NSString stringWithFormat:@"%g", [[self advancedDefaults][key] doubleValue]] forKey:@"placeholder"];
    [s setProperty:[L16EditCell class] forKey:@"cellClass"];
    [s setProperty:@"numbers" forKey:@"keyboard"];
    return s;
}

- (PSSpecifier *)button:(NSString *)name action:(SEL)action {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:name target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    s.buttonAction = action;
    return s;
}

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;
    NSMutableArray *s = [NSMutableArray array];
    BOOL const advanced = [[self storedValue:@"advancedMode"] boolValue];

    [s addObject:[self group:nil footer:@"Feature toggles and the status bar model apply after a respring. Sizes apply right away, but the status bar may only fully redraw after a respring."]];
    [s addObject:[self toggle:@"Enabled" key:@"enabled" def:YES]];

    [s addObject:[self group:@"Features" footer:@"Left-aligned clock keeps the clock at a fixed distance from the edge instead of centring it, so wider times like 05:42 don't shift it."]];
    [s addObject:[self toggle:@"iPhone X Status Bar" key:@"statusBar" def:YES]];
    [s addObject:[self toggle:@"Left-Aligned Clock" key:@"clockLeftAligned" def:NO]];
    [s addObject:[self toggle:@"Lock Screen Flashlight & Camera" key:@"quickActions" def:YES]];
    [s addObject:[self toggle:@"Control Center From Top Right" key:@"controlCenterTopRight" def:YES]];
    [s addObject:[self toggle:@"Hide Home Bar" key:@"hideHomeBar" def:YES]];

    [s addObject:[self group:nil footer:nil]];
    [s addObject:[PSSpecifier preferenceSpecifierNamed:@"Help" target:self set:nil get:nil detail:[L16HelpController class] cell:PSLinkCell edit:nil]];

    [s addObject:[self group:@"Mode" footer:advanced
        ? @"Advanced values are kept separately from simple ones. Long press a field to reset it to the default. An empty field silently uses the default."
        : @"Simple mode adjusts the status bar with three sliders. Tap a slider to type a value, or long press it to reset. Advanced mode lets you set every value on its own."]];
    [s addObject:[self toggle:@"Advanced Mode" key:@"advancedMode" def:NO]];

    if (!advanced) {
        [s addObject:[self group:@"App Top Padding" footer:@"Space apps leave for the status bar, in points. Default 24."]];
        [s addObject:[self slider:@"s_barHeight" def:24 min:16 max:44]];
        [s addObject:[self group:@"Status Bar Vertical Offset" footer:@"How far the status bar items are pushed down. Default 6."]];
        [s addObject:[self slider:@"s_barOffset" def:6 min:0 max:16]];
        [s addObject:[self group:@"Side Margin" footer:@"Distance of the battery side from the screen edge; the clock is matched to it. Default 22."]];
        [s addObject:[self slider:@"s_sideMargin" def:22 min:4 max:40]];
    } else {

        [s addObject:[self group:@"Status Bar" footer:@"Model picks which notched iPhone's status bar layout to use. Padding is the space apps and the screenshot editor leave at the top."]];
        PSSpecifier *model = [self cell:PSLinkListCell name:@"Model" key:@"a_statusBarModel" def:@"Split1125"];
        model.detailControllerClass = NSClassFromString(@"PSListItemsController");
        [model setValues:@[@"Split1125", @"Split828", @"Split1242", @"Split1080", @"Split1170", @"Split1284"] titles:@[@"iPhone X / XS / 11 Pro", @"iPhone XR / 11", @"iPhone XS Max / 11 Pro Max", @"iPhone 12 / 13 mini", @"iPhone 12 / 13 / 14", @"iPhone 12 / 13 Pro Max"]];
        [s addObject:model];
        [s addObject:[self number:@"App Top Padding" key:@"a_appPadding"]];
        [s addObject:[self number:@"Screenshot Editor Padding" key:@"a_editorPadding"]];

        [s addObject:[self group:@"Clock" footer:@"Top is added to the layout's own top spacing. Inset is the distance from the left edge of the clock's area."]];
        [s addObject:[self number:@"Top Offset" key:@"a_timeTop"]];
        [s addObject:[self number:@"Edge Inset" key:@"a_timeInset"]];

        [s addObject:[self group:@"Battery Side" footer:@"Same as the clock, for the signal, Wi-Fi and battery side."]];
        [s addObject:[self number:@"Top Offset" key:@"a_iconsTop"]];
        [s addObject:[self number:@"Edge Inset" key:@"a_iconsInset"]];

        [s addObject:[self group:@"Lock Screen" footer:@"Button values position the flashlight and camera buttons. The notification list offset only applies on iOS 16."]];
        [s addObject:[self number:@"Button Side Inset" key:@"a_qaSideInset"]];
        [s addObject:[self number:@"Button Bottom Offset" key:@"a_qaBottom"]];
        [s addObject:[self number:@"Button Size" key:@"a_qaSize"]];
        [s addObject:[self number:@"Bottom Safe Area" key:@"a_lockBottomInset"]];
        [s addObject:[self number:@"Fullscreen Notification Y" key:@"a_fullscreenNotifY"]];
        [s addObject:[self number:@"Notification List Y" key:@"a_notifListY"]];

        [s addObject:[self group:nil footer:@"Fills the status bar fields above with the values your simple sliders currently give."]];
        [s addObject:[self button:@"Copy Simple Values to Advanced" action:@selector(copySimple)]];
    }

    [s addObject:[self group:nil footer:nil]];
    [s addObject:[self button:@"Reset All Settings" action:@selector(confirmReset)]];
    [s addObject:[self button:@"Respring" action:@selector(respring)]];

    _specifiers = s;
    return _specifiers;
}

- (void)copySimple {
    [[self simpleDerived] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *value, BOOL *stop) {
        [self store:[NSString stringWithFormat:@"%g", value.doubleValue] key:key];
    }];
    [self notifyTweak];
    [self reloadSpecifiers];
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Little16?" message:@"Every setting, simple and advanced, goes back to its default." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        CFArrayRef keys = CFPreferencesCopyKeyList(L16_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (keys) {
            CFPreferencesSetMultiple(NULL, keys, L16_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
            CFRelease(keys);
        }
        CFPreferencesAppSynchronize(L16_DOMAIN);
        [self notifyTweak];
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)respring {
    pid_t pid;
    const char *args[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)args, NULL);
}

@end
