//
//  ChatService.m
//  sample-chat
//
//  Created by Igor Khomenko on 10/21/13.
//  Copyright (c) 2013 Igor Khomenko. All rights reserved.
//

#import "ChatService.h"

typedef void(^CompletionBlock)();
typedef void(^JoinRoomCompletionBlock)(QBChatRoom *);
typedef void(^CompletionBlockWithResult)(NSArray *);

@interface ChatService () <QBChatDelegate>

@property (copy) QBUUser *currentUser;
@property (retain) NSTimer *presenceTimer;

@property (copy) CompletionBlock loginCompletionBlock;
@property (copy) JoinRoomCompletionBlock joinRoomCompletionBlock;

@end


@implementation ChatService

+ (instancetype)instance{
    static id instance_ = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance_ = [[self alloc] init];
	});
	
	return instance_;
}

- (id)init{
    self = [super init];
    if(self){
        [[QBChat instance] addDelegate:self];
        //
        [QBChat instance].autoReconnectEnabled = YES;
        //
        [QBChat instance].streamManagementEnabled = YES;
    }
    return self;
}

- (void)loginWithUser:(QBUUser *)user completionBlock:(void(^)())completionBlock{
    self.loginCompletionBlock = completionBlock;
    
    self.currentUser = user;
    
    [[QBChat instance] loginWithUser:user];
}

- (void)logout{
    [[QBChat instance] logout];
}

- (void)sendMessage:(QBChatMessage *)message{
    [[QBChat instance] sendMessage:message];
}

- (void)sendMessage:(QBChatMessage *)message sentBlock:(void (^)(NSError *error))sentBlock{
    [[QBChat instance] sendMessage:message sentBlock:^(NSError *error) {
        sentBlock(error);
    }];
}

- (void)sendMessage:(QBChatMessage *)message toRoom:(QBChatRoom *)chatRoom{
    [[QBChat instance] sendChatMessage:message toRoom:chatRoom];
}

- (void)joinRoom:(QBChatRoom *)room completionBlock:(void(^)(QBChatRoom *))completionBlock{
    self.joinRoomCompletionBlock = completionBlock;
    
    [room joinRoomWithHistoryAttribute:@{@"maxstanzas": @"0"}];
}

- (void)leaveRoom:(QBChatRoom *)room{
    [[QBChat instance] leaveRoom:room];
}


#pragma mark
#pragma mark QBChatDelegate

- (void)chatDidLogin{
    // Start sending presences
    [self.presenceTimer invalidate];
    self.presenceTimer = [NSTimer scheduledTimerWithTimeInterval:30
                                     target:[QBChat instance] selector:@selector(sendPresence)
                                   userInfo:nil repeats:YES];
    
    if(self.loginCompletionBlock != nil){
        self.loginCompletionBlock();
        self.loginCompletionBlock = nil;
    }
}

- (void)chatDidFailWithError:(NSInteger)code{
    // relogin here
    [[QBChat instance] loginWithUser:self.currentUser];
}

- (void)chatRoomDidEnter:(QBChatRoom *)room{
    self.joinRoomCompletionBlock(room);
    self.joinRoomCompletionBlock = nil;
}

- (void)chatDidReceiveMessage:(QBChatMessage *)message{
    
    // notify observers
    BOOL processed = NO;
    if([self.delegate respondsToSelector:@selector(chatDidReceiveMessage:)]){
        processed = [self.delegate chatDidReceiveMessage:message];
    }
    
    if(!processed){
        [[TWMessageBarManager sharedInstance] showMessageWithTitle:@"New message"
                                                       description:message.text
                                                              type:TWMessageBarMessageTypeInfo];
        
        [[SoundService instance] playNotificationSound];
    }
}

- (void)chatRoomDidReceiveMessage:(QBChatMessage *)message fromRoomJID:(NSString *)roomJID{
    
    // notify observers
    BOOL processed = NO;
    if([self.delegate respondsToSelector:@selector(chatRoomDidReceiveMessage:fromRoomJID:)]){
        processed = [self.delegate chatRoomDidReceiveMessage:message fromRoomJID:roomJID];
    }
    
    if(!processed){
        [[TWMessageBarManager sharedInstance] showMessageWithTitle:@"New message"
                                                       description:message.text
                                                              type:TWMessageBarMessageTypeInfo];
        
        [[SoundService instance] playNotificationSound];
    }
}


@end
