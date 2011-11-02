/*=========================================================================
 Program:   OsiriX
 
 Copyright (c) OsiriX Team
 All rights reserved.
 Distributed under GNU - LGPL
 
 See http://www.osirix-viewer.com/copyright.html for details.
 
 This software is distributed WITHOUT ANY WARRANTY; without even
 the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 PURPOSE.
 =========================================================================*/


#import "ThreadModalForWindowController.h"
#import "ThreadsManager.h"
#import "NSThread+N2.h"
#import "N2Debug.h"


NSString* const NSThreadModalForWindowControllerKey = @"ThreadModalForWindowController";


@implementation ThreadModalForWindowController

@synthesize thread = _thread;
@synthesize docWindow = _docWindow;
@synthesize progressIndicator = _progressIndicator;
@synthesize cancelButton = _cancelButton;
@synthesize titleField = _titleField;
@synthesize statusField = _statusField;
@synthesize progressDetailsField = _progressDetailsField;

-(id)initWithThread:(NSThread*)thread window:(NSWindow*)docWindow {
	self = [super initWithWindowNibName:@"ThreadModalForWindow"];
	
	_docWindow = [docWindow retain];
	_thread = [thread retain];
	[thread.threadDictionary setObject:self forKey:NSThreadModalForWindowControllerKey];
    
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(threadWillExitNotification:) name:NSThreadWillExitNotification object:_thread];

	[NSApp beginSheet:self.window modalForWindow:self.docWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
    
	[self retain];

	return self;	
}

static NSString* ThreadModalForWindowControllerObservationContext = @"ThreadModalForWindowControllerObservationContext";

-(void)awakeFromNib {
	[self.progressIndicator setMinValue:0];
	[self.progressIndicator setMaxValue:1];
	[self.progressIndicator setUsesThreadedAnimation:NO];
	[self.progressIndicator startAnimation:self];
	
    [self.titleField bind:@"value" toObject:self.thread withKeyPath:NSThreadNameKey options:NULL];
//  [self.window bind:@"title" toObject:self.thread withKeyPath:NSThreadNameKey options:NULL];
    [self.statusField bind:@"value" toObject:self.thread withKeyPath:NSThreadStatusKey options:NULL];
    [self.progressDetailsField bind:@"value" toObject:self.thread withKeyPath:NSThreadProgressDetailsKey options:NULL];
    [self.cancelButton bind:@"hidden" toObject:self.thread withKeyPath:NSThreadSupportsCancelKey options:[NSDictionary dictionaryWithObject:NSNegateBooleanTransformerName forKey:NSValueTransformerNameBindingOption]];
	[self.cancelButton bind:@"hidden2" toObject:self.thread withKeyPath:NSThreadIsCancelledKey options:NULL];
	
	[self.thread addObserver:self forKeyPath:NSThreadProgressKey options:NSKeyValueObservingOptionInitial context:ThreadModalForWindowControllerObservationContext];
	[self.thread addObserver:self forKeyPath:NSThreadNameKey options:NSKeyValueObservingOptionInitial context:ThreadModalForWindowControllerObservationContext];
	[self.thread addObserver:self forKeyPath:NSThreadStatusKey options:NSKeyValueObservingOptionInitial context:ThreadModalForWindowControllerObservationContext];
	[self.thread addObserver:self forKeyPath:NSThreadProgressDetailsKey options:NSKeyValueObservingOptionInitial context:ThreadModalForWindowControllerObservationContext];
	[self.thread addObserver:self forKeyPath:NSThreadSupportsCancelKey options:NSKeyValueObservingOptionInitial context:ThreadModalForWindowControllerObservationContext];
	[self.thread addObserver:self forKeyPath:NSThreadIsCancelledKey options:NSKeyValueObservingOptionInitial context:ThreadModalForWindowControllerObservationContext];
}

-(void)sheetDidEndOnMainThread:(NSWindow*)sheet
{
	[sheet orderOut:self];
//	[NSApp endSheet:sheet];
	[self release];
}

-(void)sheetDidEnd:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo {
	[self performSelectorOnMainThread:@selector(sheetDidEndOnMainThread:) withObject:sheet waitUntilDone:NO];
}

-(void)dealloc {
	DLog(@"[ThreadModalForWindowController dealloc]");
	
	[self.thread removeObserver:self forKeyPath:NSThreadProgressKey];
	[self.thread removeObserver:self forKeyPath:NSThreadNameKey];
	[self.thread removeObserver:self forKeyPath:NSThreadStatusKey];
	[self.thread removeObserver:self forKeyPath:NSThreadProgressDetailsKey];
	[self.thread removeObserver:self forKeyPath:NSThreadSupportsCancelKey];
	[self.thread removeObserver:self forKeyPath:NSThreadIsCancelledKey];
	
	[_thread release];
	[_docWindow release];
	
	[super dealloc]; 
}

-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)obj change:(NSDictionary*)change context:(void*)context {
	if (context == ThreadModalForWindowControllerObservationContext) {
		if ([keyPath isEqual:NSThreadProgressKey]) {
			[self.progressIndicator setIndeterminate: self.thread.progress < 0];	
			if (self.thread.progress >= 0)
				[self.progressIndicator setDoubleValue:self.thread.subthreadsAwareProgress];
		}
        
        if ([NSThread isMainThread]) {
            if ([keyPath isEqual:NSThreadProgressKey])
                [self.progressIndicator display];
            if ([keyPath isEqual:NSThreadNameKey])
                [self.titleField display];
            if ([keyPath isEqual:NSThreadStatusKey])
                [self.statusField display];
            if ([keyPath isEqual:NSThreadProgressDetailsKey])
                [self.progressDetailsField display];
            if ([keyPath isEqual:NSThreadSupportsCancelKey])
                [self.cancelButton display];
            if ([keyPath isEqual:NSThreadIsCancelledKey])
                [self.cancelButton display];
        }
        
        return;
	}
        
	[super observeValueForKeyPath:keyPath ofObject:obj change:change context:context];
}

-(void)invalidate {
	DLog(@"[ThreadModalForWindowController invalidate]");
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSThreadWillExitNotification object:_thread];
	[self.thread.threadDictionary removeObjectForKey:NSThreadModalForWindowControllerKey];
    
	if ([NSThread isMainThread]) 
		[NSApp endSheet:self.window];
	else [NSApp performSelectorOnMainThread:@selector(endSheet:) withObject:self.window waitUntilDone:NO];
//    if (![self.window isSheet]) {
//        if ([NSThread isMainThread]) 
//            [self.window orderOut:self];
//        else [self.window performSelectorOnMainThread:@selector(orderOut:) withObject:self waitUntilDone:NO];
//    }
    
}

-(void)threadWillExitNotification:(NSNotification*)notification {
	[self invalidate];
}

-(void)cancelAction:(id)source {
	[self.thread setIsCancelled:YES];
}

@end

@implementation NSThread (ModalForWindow)

-(ThreadModalForWindowController*)startModalForWindow:(NSWindow*)window {
//	if ([[self threadDictionary] objectForKey:ThreadIsCurrentlyModal])
//		return nil;
//	[[self threadDictionary] setObject:[NSNumber numberWithBool:YES] forKey:ThreadIsCurrentlyModal];
	if ([NSThread isMainThread]) {
		if (![self isFinished])
			return [[[ThreadModalForWindowController alloc] initWithThread:self window:window] autorelease];
	} else [self performSelectorOnMainThread:@selector(startModalForWindow:) withObject:window waitUntilDone:NO];
	return nil;
}

-(ThreadModalForWindowController*)modalForWindowController {
	return [self.threadDictionary objectForKey:NSThreadModalForWindowControllerKey];
}

@end


