#import "AppDelegate.h"
#import <Carbon/Carbon.h>

@interface AppDelegate ()

@property (nonatomic, assign) BOOL commandShiftPressed; // Track if Command + Shift was pressed

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
        // Re-enable the event tap if it gets disabled due to timeout
        CGEventTapEnable(self.eventTap, true);
        return NULL;
    }
    
    NSEvent *nsEvent = [NSEvent eventWithCGEvent:event];
    NSEventModifierFlags modifiers = nsEvent.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagShift);
    
    if (type == kCGEventKeyDown) {
        // If any key (not a modifier) is pressed while Command+Shift is active, cancel the tracking
        if (self.commandShiftPressed && ![self isModifierKey:nsEvent]) {
            self.commandShiftPressed = NO;
            NSLog(@"Cancelled Command+Shift tracking because another key was pressed");
        }
    } else if (type == kCGEventFlagsChanged) {
        // Check if both Command and Shift are pressed
        if (modifiers == (NSEventModifierFlagCommand | NSEventModifierFlagShift)) {
            if (!self.commandShiftPressed) {
                self.commandShiftPressed = YES; // Mark as Command + Shift pressed
                NSLog(@"Command+Shift pressed");
            }
        } 
        // Check if Command+Shift was previously pressed and now both are released
        else if (self.commandShiftPressed && modifiers == 0) {
            [self switchToNextKeyboardLayout];
            self.commandShiftPressed = NO; // Reset the flag
            NSLog(@"Command+Shift released, switching layout");
        } 
        // Only cancel if another modifier key like Control or Option is pressed
        else if (self.commandShiftPressed && 
                (nsEvent.modifierFlags & (NSEventModifierFlagControl | NSEventModifierFlagOption))) {
            self.commandShiftPressed = NO;
            NSLog(@"Cancelled Command+Shift tracking due to other modifier key pressed");
        }
        // Otherwise keep tracking - one of Command or Shift might still be down
    }
    
    return event;
}

// Helper method to check if the key is a modifier key
- (BOOL)isModifierKey:(NSEvent *)event {
    return event.keyCode == kVK_Command || event.keyCode == kVK_Shift ||
           event.keyCode == kVK_Control || event.keyCode == kVK_Option;
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