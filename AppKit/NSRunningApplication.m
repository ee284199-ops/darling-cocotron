#import <AppKit/NSRunningApplication.h>

// Only the current application is known so far; the notes below are how
// AppKit finds the others through LaunchServices.

// Implementation notes:
// _LSCopyApplicationInformationItem(-2, ...) is used to fetch properties, such
// as _kLSExecutablePathKey Applications (processes) are referred to by an
// opaque void* asn (application serial number). ASNs can be compared with
// _LSCompareASNs().
//
// lsd provides notifications when processes change. This is registered via:
// _LSScheduleNotificationFunction(-2, callback, eventMask, context,
// CFRunLoopRef, kCFRunLoopCommonModes) and _LSModifyNotification(). The
// properties are updated via KVO.
//
// Current application is also observed via LS - _LSGetCurrentApplicationASN().
// All apps: _LSCopyRunningApplicationArray() - returns an array of ASNs.
// Running apps: _LSCopyRunningApplicationArray() - ditto.

#import <AppKit/NSApplication.h>
#import <AppKit/NSImage.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSURL.h>
#include <signal.h>
#include <unistd.h>

// NSBundleExecutableArchitectureX86_64
#define NSRUNNINGAPPLICATION_ARCHITECTURE 0x01000007

@implementation NSRunningApplication

+ (instancetype) currentApplication {
    static NSRunningApplication *current = nil;

    @synchronized(self) {
        if (current == nil) {
            NSBundle *bundle = [NSBundle mainBundle];
            NSString *name = [bundle objectForInfoDictionaryKey: @"CFBundleDisplayName"];

            if (name == nil)
                name = [bundle objectForInfoDictionaryKey: @"CFBundleName"];
            if (name == nil)
                name = [[NSProcessInfo processInfo] processName];

            current = [[NSRunningApplication alloc] init];
            current->_processIdentifier = getpid();
            current->_bundleIdentifier = [[bundle bundleIdentifier] copy];
            current->_bundleURL = [[bundle bundleURL] copy];
            current->_executableURL = [[bundle executableURL] copy];
            current->_localizedName = [name copy];
            // close enough: this is asked for early on
            current->_launchDate = [[NSDate date] retain];
        }
    }
    return current;
}

+ (instancetype) runningApplicationWithProcessIdentifier: (pid_t) pid {
    if (pid == getpid())
        return [self currentApplication];
    return nil;
}

+ (NSArray<NSRunningApplication *> *) runningApplicationsWithBundleIdentifier: (NSString *) bundleIdentifier {
    NSRunningApplication *current = [self currentApplication];

    if (bundleIdentifier != nil &&
        [bundleIdentifier isEqualToString: [current bundleIdentifier]])
        return [NSArray arrayWithObject: current];
    return [NSArray array];
}

+ (void) terminateAutomaticallyTerminableApplications {
}

- (void) dealloc {
    [_bundleIdentifier release];
    [_bundleURL release];
    [_executableURL release];
    [_localizedName release];
    [_launchDate release];
    [super dealloc];
}

- (BOOL) isCurrent {
    return _processIdentifier == getpid();
}

- (pid_t) processIdentifier {
    return _processIdentifier;
}

- (NSString *) bundleIdentifier {
    return _bundleIdentifier;
}

- (NSURL *) bundleURL {
    return _bundleURL;
}

- (NSURL *) executableURL {
    return _executableURL;
}

- (NSString *) localizedName {
    return _localizedName;
}

- (NSDate *) launchDate {
    return _launchDate;
}

- (NSImage *) icon {
    return [self isCurrent] ? [NSApp applicationIconImage] : nil;
}

- (NSApplicationActivationPolicy) activationPolicy {
    if ([self isCurrent] && NSApp != nil)
        return [NSApp activationPolicy];
    return NSApplicationActivationPolicyRegular;
}

- (BOOL) isActive {
    return [self isCurrent] && [NSApp isActive];
}

- (BOOL) isHidden {
    return [self isCurrent] && [NSApp isHidden];
}

- (BOOL) isFinishedLaunching {
    return [self isCurrent] && [NSApp isRunning];
}

- (BOOL) isTerminated {
    return ![self isCurrent] && kill(_processIdentifier, 0) != 0;
}

- (BOOL) ownsMenuBar {
    return [self isActive];
}

- (NSInteger) executableArchitecture {
    return NSRUNNINGAPPLICATION_ARCHITECTURE;
}

- (BOOL) activateWithOptions: (NSApplicationActivationOptions) options {
    if (![self isCurrent])
        return NO;
    [NSApp activateIgnoringOtherApps:
                   (options & NSApplicationActivateIgnoringOtherApps) != 0];
    return YES;
}

- (BOOL) hide {
    if (![self isCurrent])
        return NO;
    [NSApp hide: nil];
    return YES;
}

- (BOOL) unhide {
    if (![self isCurrent])
        return NO;
    [NSApp unhide: nil];
    return YES;
}

- (BOOL) terminate {
    if ([self isCurrent]) {
        [NSApp terminate: nil];
        return YES;
    }
    return kill(_processIdentifier, SIGTERM) == 0;
}

- (BOOL) forceTerminate {
    return kill(_processIdentifier, SIGKILL) == 0;
}

@end
