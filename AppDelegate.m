#import "AppDelegate.h"
#import <Carbon/Carbon.h>

typedef NS_ENUM(NSUInteger, CommandShiftState) {
    CommandShiftIdle,
    CommandShiftArmed,
    CommandShiftConsumed,
};

@interface AppDelegate ()

@property (nonatomic, assign) CommandShiftState commandShiftState;

- (void)switchToNextKeyboardLayout;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupGlobalKeyListener];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self tearDownGlobalKeyListener];
}

- (void)setupGlobalKeyListener {
    CGEventMask eventMask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged);
    self.eventTap = CGEventTapCreate(kCGSessionEventTap,
                                     kCGHeadInsertEventTap,
                                     0,
                                     eventMask,
                                     eventTapCallback,
                                     (__bridge void *)(self));
    
    if (!self.eventTap) {
        NSLog(@"Failed to create event tap. Check accessibility permissions.");
        [self showPermissionAlert];
        return;
    }
    
    self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), self.runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(self.eventTap, true);
}

- (void)tearDownGlobalKeyListener {
    if (self.eventTap) {
        CGEventTapEnable(self.eventTap, false);
        CFMachPortInvalidate(self.eventTap);
        CFRelease(self.eventTap);
        self.eventTap = NULL;
    }
    if (self.runLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), self.runLoopSource, kCFRunLoopCommonModes);
        CFRelease(self.runLoopSource);
        self.runLoopSource = NULL;
    }
}

- (void)showPermissionAlert {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Accessibility Permission Required";
    alert.informativeText = @"Enable this app in System Preferences > Security & Privacy > Accessibility.";
    [alert addButtonWithTitle:@"Open Settings"];
    [alert addButtonWithTitle:@"Quit"];
    
    NSInteger response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
    }
    [NSApp terminate:nil];
}

CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    AppDelegate *self = (__bridge AppDelegate *)userInfo;

    if (type == kCGEventTapDisabledByTimeout) {
        self.commandShiftState = CommandShiftConsumed;
        CGEventTapEnable(self.eventTap, true);
        return NULL;
    }

    if (type == kCGEventKeyDown) {
        if (self.commandShiftState == CommandShiftArmed) {
            self.commandShiftState = CommandShiftConsumed;
        }
        return event;
    }

    const CGEventFlags chord = kCGEventFlagMaskCommand | kCGEventFlagMaskShift;
    const CGEventFlags otherModifiers = kCGEventFlagMaskControl | kCGEventFlagMaskAlternate |
                                        kCGEventFlagMaskSecondaryFn;
    CGEventFlags flags = CGEventGetFlags(event);
    CGEventFlags modifiers = flags & chord;

    if (modifiers == chord && self.commandShiftState == CommandShiftIdle) {
        self.commandShiftState = CommandShiftArmed;
    }
    if ((flags & otherModifiers) && self.commandShiftState == CommandShiftArmed) {
        self.commandShiftState = CommandShiftConsumed;
    }
    // The next event can already be Cmd+Tab if Shift is released first.
    if (modifiers != chord && self.commandShiftState == CommandShiftArmed) {
        self.commandShiftState = CommandShiftConsumed;
        [self switchToNextKeyboardLayout];
    }
    if (modifiers == 0) {
        self.commandShiftState = CommandShiftIdle;
    }

    return event;
}

- (void)switchToNextKeyboardLayout {
    NSArray *sources = CFBridgingRelease(TISCreateInputSourceList((__bridge CFDictionaryRef)@{
        (__bridge NSString *)kTISPropertyInputSourceCategory: (__bridge NSString *)kTISCategoryKeyboardInputSource,
        (__bridge NSString *)kTISPropertyInputSourceIsSelectCapable: @YES
    }, false));
    if (sources.count == 0) {
        return;
    }

    TISInputSourceRef current = TISCopyCurrentKeyboardInputSource();
    NSUInteger index = current ? [sources indexOfObject:(__bridge id)current] : NSNotFound;
    if (current) {
        CFRelease(current);
    }
    index = index == NSNotFound ? 0 : (index + 1) % sources.count;

    TISInputSourceRef next = (__bridge TISInputSourceRef)sources[index];
    OSStatus status = TISSelectInputSource(next);
    if (status != noErr) {
        NSLog(@"Failed to switch keyboard layout (OSStatus %d).", (int)status);
    }
}

@end
