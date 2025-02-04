#import "AppDelegate.h"
#import <Carbon/Carbon.h>

@interface AppDelegate ()


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
        CGEventTapEnable(self.eventTap, true);
        return NULL;
    }
    
    NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];
    NSEventModifierFlags modifiers = nsEvent.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagShift);
    
    if ((modifiers == (NSEventModifierFlagCommand | NSEventModifierFlagShift))) {
        [self switchToNextKeyboardLayout];
    }
    
    return event;
}

- (void)switchToNextKeyboardLayout {
    NSArray *sources = CFBridgingRelease(TISCreateInputSourceList((__bridge CFDictionaryRef)@{
        (__bridge NSString *)kTISPropertyInputSourceCategory: (__bridge NSString *)kTISCategoryKeyboardInputSource,
        (__bridge NSString *)kTISPropertyInputSourceIsSelectCapable: @YES
    }, false));
    
    NSLog(@"Number of keyboard sources: %lu", (unsigned long)sources.count);
    
    for (id source in sources) {
        NSString *name = (__bridge NSString *)TISGetInputSourceProperty((__bridge TISInputSourceRef)source, kTISPropertyLocalizedName);
        NSString *sourceID = (__bridge NSString *)TISGetInputSourceProperty((__bridge TISInputSourceRef)source, kTISPropertyInputSourceID);
        NSLog(@"Available source: %@ (ID: %@)", name, sourceID);
    }
    
    TISInputSourceRef current = TISCopyCurrentKeyboardInputSource();
    NSString *currentName = (__bridge NSString *)TISGetInputSourceProperty(current, kTISPropertyLocalizedName);
    NSString *currentID = (__bridge NSString *)TISGetInputSourceProperty(current, kTISPropertyInputSourceID);
    NSLog(@"Current keyboard source: %@ (ID: %@)", currentName, currentID);
    
    NSUInteger index = [sources indexOfObject:(__bridge id)current];
    CFRelease(current);
    
    if (index == NSNotFound) {
        NSLog(@"Current source not found in available sources. Defaulting to first source.");
        index = 0;
    } else {
        index = (index + 1) % sources.count;
    }
    
    TISInputSourceRef next = (__bridge TISInputSourceRef)sources[index];
    NSString *nextName = (__bridge NSString *)TISGetInputSourceProperty(next, kTISPropertyLocalizedName);
    NSString *nextID = (__bridge NSString *)TISGetInputSourceProperty(next, kTISPropertyInputSourceID);
    NSLog(@"Attempting to switch to: %@ (ID: %@)", nextName, nextID);
    
    Boolean success = TISSelectInputSource(next);
    if (success) {
        NSLog(@"Successfully switched keyboard layout.");
    } else {
        NSLog(@"Failed to switch keyboard layout.");
    }
}

@end