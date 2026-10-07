/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#import <Foundation/NSObject.h>
#include <sys/types.h>

@class NSArray, NSDate, NSImage, NSString, NSURL;

typedef enum {
    NSApplicationActivationPolicyRegular,
    NSApplicationActivationPolicyAccessory,
    NSApplicationActivationPolicyProhibited
} NSApplicationActivationPolicy;

typedef NS_OPTIONS(NSUInteger, NSApplicationActivationOptions) {
    NSApplicationActivateAllWindows = 1 << 0,
    NSApplicationActivateIgnoringOtherApps = 1 << 1,
};

// Only the current application is known; other processes aren't tracked yet.
@interface NSRunningApplication : NSObject {
    pid_t _processIdentifier;
    NSString *_bundleIdentifier;
    NSURL *_bundleURL;
    NSURL *_executableURL;
    NSString *_localizedName;
    NSDate *_launchDate;
}

+ (instancetype) currentApplication;
+ (instancetype) runningApplicationWithProcessIdentifier: (pid_t) pid;
+ (NSArray<NSRunningApplication *> *) runningApplicationsWithBundleIdentifier: (NSString *) bundleIdentifier;
+ (void) terminateAutomaticallyTerminableApplications;

@property(readonly) pid_t processIdentifier;
@property(readonly, copy) NSString *bundleIdentifier;
@property(readonly, copy) NSURL *bundleURL;
@property(readonly, copy) NSURL *executableURL;
@property(readonly, copy) NSString *localizedName;
@property(readonly, copy) NSDate *launchDate;
@property(readonly, retain) NSImage *icon;
@property(readonly) NSApplicationActivationPolicy activationPolicy;
@property(readonly, getter=isActive) BOOL active;
@property(readonly, getter=isHidden) BOOL hidden;
@property(readonly, getter=isFinishedLaunching) BOOL finishedLaunching;
@property(readonly, getter=isTerminated) BOOL terminated;
@property(readonly) BOOL ownsMenuBar;
@property(readonly) NSInteger executableArchitecture;

- (BOOL) activateWithOptions: (NSApplicationActivationOptions) options;
- (BOOL) hide;
- (BOOL) unhide;
- (BOOL) terminate;
- (BOOL) forceTerminate;

@end
