
/*

 Copyright (c) 2008, Alex Jones
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that
 the following conditions are met:
 
 	1.	Redistributions of source code must retain the above copyright notice, this list of conditions and the
 		following disclaimer.
  
 	2.	Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
 		the following disclaimer in the documentation and/or other materials provided with the distribution.
  
 	3.	Neither the name of MacServe nor the names of its contributors may be used to endorse
 		or promote products derived from this software without specific prior written permission.
  
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 */

#import "MSController.h"

@interface MSController()

- (void)_readData:(NSNotification *)notification;

@end

@implementation MSController

NSString * const processName = @"ssh";


- (void)awakeFromNib {
	
	if([ self checkStatus ] == 0) {
		
		[ self setButtonsConnected ];
	}
	
	[self loadSettings:self];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
	
	if(flag == NO){
		[ mainWindow makeKeyAndOrderFront:nil ];
		
	}
	else {
		if([ mainWindow isVisible ] == NO) {
			[ mainWindow makeKeyAndOrderFront:nil ];
		}
	}
	
	return NO;
	
}

- (IBAction)openPreferences:(id)sender {
	
	[ preferencesWindow makeKeyAndOrderFront:nil ];
	
}
	
- (IBAction)loadSettings:(id)sender {
    
	defaults = [ NSUserDefaults standardUserDefaults ];
	NSString* str = nil;
	[ remoteAddress setStringValue: (str = [ defaults objectForKey: @"remoteAddress" ]) ? str :  @""];
	[ userName setStringValue: (str = [ defaults objectForKey: @"userName" ]) ? str :  @""];
	[ portNumber setStringValue: (str = [ defaults objectForKey: @"portNumber" ]) ? str :  @""];
	[ localPort setStringValue: (str = [ defaults objectForKey: @"localPort" ]) ? str :  @""];
	[ remotePort setStringValue: (str = [ defaults objectForKey: @"remotePort" ]) ? str :  @""];
	[ socksPort setStringValue: (str = [ defaults objectForKey: @"socksPort" ]) ? str :  @""];
	[ obfuscatedKey setStringValue: (str = [ defaults objectForKey: @"obfuscatedKey" ]) ? str :  @""];

	if([[ EMKeychainProxy sharedProxy ] genericKeychainItemForService: @"iSSH" withUsername: @"MacServe" ] != nil) {
	[ passWord setStringValue: [[[ EMKeychainProxy sharedProxy ] genericKeychainItemForService: @"iSSH" withUsername: @"MacServe" ] password ]];
	}
	
}

- (IBAction)saveSettings:(id)sender {

	if([ self checkFields ] == 1) {
		return;
	}
	
    defaults = [ NSUserDefaults standardUserDefaults ];
	[ defaults setObject:[ remoteAddress stringValue ] forKey: @"remoteAddress" ];
	[ defaults setObject:[ userName stringValue ] forKey: @"userName" ];
	[ defaults setObject:[ portNumber stringValue ] forKey: @"portNumber" ];
	[ defaults setObject:[ localPort stringValue ] forKey: @"localPort" ];
	[ defaults setObject:[ remotePort stringValue ] forKey: @"remotePort" ];
	[ defaults setObject:[ socksPort stringValue ] forKey: @"socksPort" ];
	[ defaults setObject:[ obfuscatedKey stringValue ] forKey: @"obfuscatedKey" ];
	
	if([[ EMKeychainProxy sharedProxy ] genericKeychainItemForService: @"iSSH" withUsername: @"MacServe" ] == nil) {
		[[ EMKeychainProxy sharedProxy ] addGenericKeychainItemForService: @"iSSH" withUsername: @"MacServe" password: [ passWord stringValue ]];		
	}
	else {
		[[[ EMKeychainProxy sharedProxy ] genericKeychainItemForService: @"iSSH" withUsername: @"MacServe" ] setPassword: [ passWord stringValue ]];
	}
	
}

- (IBAction)startCon:(id)sender {
	
    [ self launch ];
	
}

- (IBAction)stopCon:(id)sender {

	[ self terminate ];
	
	[ self setButtonsDisconnected ];
	
}

- (IBAction)stopConQuit:(id)sender {

	[ self terminate ];
    [ NSApp terminate: self ];
    
}

- (IBAction)isshHelp:(id)sender {
	
	[[ NSWorkspace sharedWorkspace ] openURL: [ NSURL URLWithString: @"http://www.macserve.org.uk/help/issh/"]];
	
}

- (void)launch {

	[ progIndicator startAnimation:progIndicator ];
	
	if([ self checkFields ] == 1) {
		return;
	}
	
	_task = [[NSTask alloc] init];
	NSMutableDictionary *environment = [ NSMutableDictionary dictionaryWithDictionary: [[ NSProcessInfo processInfo ] environment ]];
    [ _task setLaunchPath: @"/usr/local/bin/ssh"];
	
	[ environment removeObjectForKey:@"SSH_AGENT_PID" ];
	[ environment removeObjectForKey:@"SSH_AUTH_SOCK" ];
	[ environment setObject: [[ NSBundle mainBundle ] pathForResource: @"getPass" ofType: @"sh" ] forKey: @"SSH_ASKPASS" ];
	[ environment setObject: [ passWord stringValue ] forKey: @"PASS" ];
	[ environment setObject: @":0" forKey:@"DISPLAY" ];
	[ _task setEnvironment: environment ];

    NSMutableArray *arguments = [ NSMutableArray array ];
	[ arguments addObject: @"-N" ];
	
	[ arguments addObject: [ NSString stringWithFormat: @"%@@%@", [ userName stringValue ], [ remoteAddress stringValue ] ] ];
	
	if([ portForward state ] == 1) {
	[ arguments addObject: @"-L" ];
	[ arguments addObject: [ NSString stringWithFormat: @"%@:localhost:%@", [ localPort stringValue ], [ remotePort stringValue ] ] ];
	NSLog(@"Forwarding port %@ on the local machine to port %@ on the remote machine", [ localPort stringValue ], [ remotePort stringValue ]);
	}
	else {
	[ arguments addObject: @"-D" ];
	[ arguments addObject: [ NSString stringWithFormat: @"localhost:%@", [ socksPort stringValue ] ] ];
	NSLog(@"SOCKS Proxy on port %@", [socksPort stringValue]);
	}
	
	[ arguments addObject: @"-p" ];
	if([[ portNumber stringValue ] isEqualToString:@"" ]) {
		[ arguments addObject: @"22" ];
		NSLog(@"Connecting on port 22");
	}
	else {
		
	[ arguments addObject: [ portNumber stringValue ] ];
	NSLog(@"Connecting on port %@", [ portNumber stringValue]);
	}
	
	if ([[obfuscatedKey stringValue] length])
	{
		[arguments addObject:@"-zZ"];
		[arguments addObject:[obfuscatedKey stringValue]];
	}
	
	[ arguments addObject: @"-F" ];
	[ arguments addObject: [[NSBundle mainBundle ] pathForResource: @"ssh_config" ofType: @"" ] ];
	
    [ _task setArguments: arguments ];

	// set output pipe
	_pipe = [[NSPipe alloc] init];
	[_task setStandardOutput:_pipe];
	[_task setStandardError:_pipe];
	
    [ _task launch ];
	NSLog(@"Started Connection");

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_readData:)
												 name:NSFileHandleReadCompletionNotification object:nil];
	[[_pipe fileHandleForReading] readInBackgroundAndNotify];

    [ self setButtonsConnected ];
	[ progIndicator stopAnimation:progIndicator ];
}


- (void)terminate {

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	if([ self checkStatus ] == 0) {
		
		[ _process terminate ];
		NSLog(@"Connection closed");
	}
}

- (int)checkStatus {
	
	processEnumerator = [[ AGProcess allProcesses ] objectEnumerator ];
	_process = nil;
	
	while (_process = [processEnumerator nextObject]) {
		
		if ([processName isEqualToString:[_process command]]) {
			
			return 0;
			
		}
	}
		return 1;	
}

- (void)setButtonsConnected {
	
	[ startButton setEnabled:NO ];
	[ stopButton setEnabled:YES ];
	[ stopQuitButton setEnabled:YES ];
	
}

- (void)setButtonsDisconnected {
	
	[ startButton setEnabled:YES ];
	[ stopButton setEnabled:NO ];
	[ stopQuitButton setEnabled:NO ];
	
}

- (int)checkFields {
	
	if([[ remoteAddress stringValue ] isEqualToString:@"" ]) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered an Address"], @"Ok", nil, nil);
		[ progIndicator stopAnimation:progIndicator ];
		return 1;
	}
	
	if([[ userName stringValue ] isEqualToString:@"" ]) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a User Name"], @"Ok", nil, nil);
		[ progIndicator stopAnimation:progIndicator ];
		return 1;
	}
	
	if([[ passWord stringValue ] isEqualToString:@"" ]) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a Password"], @"Ok", nil, nil);
		[ progIndicator stopAnimation:progIndicator ];
		return 1;
	}
	
	if([ portForward state ] == 1) {
		if([[ localPort stringValue ] isEqualToString:@"" ] || [[ remotePort stringValue ] isEqualToString:@"" ]) {
			NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a Port for forwarding"], @"Ok", nil, nil);
			[ progIndicator stopAnimation:progIndicator ];
			return 1;
		}
	}
	else {
		if([[ socksPort stringValue ] isEqualToString:@"" ]) {
			NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a Port for the SOCKS Proxy"], @"Ok", nil, nil);
			[ progIndicator stopAnimation:progIndicator ];
			return 1;
		}
	}
	
	return 0;
	
}

- (void)_readData:(NSNotification *)notification
{
	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
	NSString *string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	
	[output setStringValue:string];
	
	if ( [_task isRunning] )
		[[_pipe fileHandleForReading] readInBackgroundAndNotify];
	else
	{
		[_task release];
		[_pipe release];
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		
		[self setButtonsDisconnected];
		[self launch];
		
		[output setStringValue: [[output stringValue] stringByAppendingFormat:@"\n%@", @"reconnect ..."]];
	}
}

@end
