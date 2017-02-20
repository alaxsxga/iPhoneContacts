//
//  ContactsInfoManager.h
//  GetAddressBookInfo
//
//  Created by Ed on 2015/10/7.
//  Copyright © 2015年 Ed. All rights reserved.
//


#import <Foundation/Foundation.h>

@interface ContactsFromPhone : NSObject

/* 自動判斷device system version去使用新或舊API，回傳JSON格式 */
- (NSString*)contactInfoWithJsonString;

/* 同上，可給特定version */
- (NSString*)contactInfoWithJsonStringBySystemVerison:(NSString*)systemVersion;


@end
