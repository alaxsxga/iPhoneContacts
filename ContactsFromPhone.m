//
//  ContactsInfoManager.m
//  GetAddressBookInfo
//
//  Created by Ed on 2015/10/7.
//  Copyright © 2015年 Ed. All rights reserved.
//

#import "ContactsFromPhone.h"
#import <AddressBook/AddressBook.h>
#import <Contacts/Contacts.h>
#import <UIKit/UIKit.h>

#define JSON_KEY_FIRST_NAME @"firstname"
#define JSON_KEY_MIDDLE_NAME @"middlename"
#define JSON_KEY_LAST_NAME @"lastname"
#define JSON_KEY_FULL_NAME @"fullname"
#define JSON_KEY_PHONE @"phone"
#define JSON_KEY_MAIL @"mail"
#define JSON_KEY_UID @"uid"

@interface ContactsFromPhone()

@property (nonatomic, strong) NSString* contactInfoJsonString;

@end

@implementation ContactsFromPhone

- (NSString*)contactInfoWithJsonString
{
    return [self contactInfoWithJsonStringBySystemVerison:[[UIDevice currentDevice] systemVersion]];
}

- (NSString*)contactInfoWithJsonStringBySystemVerison:(NSString*)systemVersion
{
    _contactInfoJsonString = [[NSString alloc] init];
    
    /* ios9以上使用CNContactStore */
    if ([systemVersion compare:@"9.0" options:NSNumericSearch] != NSOrderedAscending) {
        [self getContactInfoWithCNContact];
        
    } else {
        [self getContactInfoWithAddressBook];
    }
    
    return _contactInfoJsonString;
}

- (void)getContactInfoWithAddressBook
{
    CFErrorRef* aberror = NULL;
    ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, aberror);
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    
    if (status == kABAuthorizationStatusDenied || status == kABAuthorizationStatusRestricted){
        
        NSLog(@"Conatct authorization denied.");
        return;
        
    } else if (status == kABAuthorizationStatusAuthorized){
        
        NSLog(@"Conatct authorization authorized.");
        _contactInfoJsonString = [self getContactDetailWithAddressBook:addressBook];
        
    /* 第一次存取通訊錄需徵求使用者同意 */
    } else if (status == kABAuthorizationStatusNotDetermined) {
        
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
            if (!granted){
                
                NSLog(@"Conatct authorization just denied");
                return;
            }
            
            NSLog(@"Conatct authorization just authorized");
            _contactInfoJsonString = [self getContactDetailWithAddressBook:addressBook];
        });
    }
}

- (void)getContactInfoWithCNContact
{
    CNContactStore* contactStore = [[CNContactStore alloc] init];
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    
    if (status == CNAuthorizationStatusDenied || status == CNAuthorizationStatusRestricted) {
        NSLog(@"Conatct authorization denied.");
        
    } else if (status == CNAuthorizationStatusAuthorized) {
        NSLog(@"Conatct authorization authorized.");
        _contactInfoJsonString = [self getContactDetailWithCNContact:contactStore];
        
    /* 第一次存取通訊錄需徵求使用者同意 */
    } else if (status == CNAuthorizationStatusNotDetermined) {
        [contactStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (!granted) {
                NSLog(@"Conatct authorization just denied");
                return;
            }
            
            NSLog(@"Conatct authorization just authorized");
            _contactInfoJsonString =[self getContactDetailWithCNContact:contactStore];
        }];
    }
}

/* iOS8以下使用ABAddressBookRef(因為已deprecated) */
- (NSString*)getContactDetailWithAddressBook:(ABAddressBookRef)addressBook
{
    CFArrayRef allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook);
    CFIndex nPeople = ABAddressBookGetPersonCount(addressBook);
    
    
    NSMutableArray* allContactInfoArray = [[NSMutableArray alloc] init];
    
    for (int i=0;i < nPeople;i++) {
        
        ABRecordRef ref = CFArrayGetValueAtIndex(allPeople,i);
        NSMutableDictionary* singleContactDic = [[NSMutableDictionary alloc] init];
        
        /* 取得名字 */
        NSString* firstName = [NSString stringWithFormat:@"%@",ABRecordCopyValue(ref, kABPersonFirstNameProperty)];
        NSString* middleName = [NSString stringWithFormat:@"%@",ABRecordCopyValue(ref, kABPersonMiddleNameProperty)];
        NSString* lastName = [NSString stringWithFormat:@"%@",ABRecordCopyValue(ref, kABPersonLastNameProperty)];
        NSString* fullName = [NSString stringWithFormat:@"%@",ABRecordCopyCompositeName(ref)];
        int32_t uid = ABRecordGetRecordID(ref);
        //若ABRecordCopyValue的值是null會回傳"(null)"字串，這邊將其改為空字串 //CFStringRef middleName = ABRecordCopyValue(ref, kABPersonMiddleNameProperty);
        if ([firstName rangeOfString:@"null"].location != NSNotFound) { firstName = @"";}
        if ([middleName rangeOfString:@"null"].location != NSNotFound) { middleName = @"";}
        if ([lastName rangeOfString:@"null"].location != NSNotFound) { lastName = @"";}
        if ([fullName rangeOfString:@"null"].location != NSNotFound) { fullName = @"";}
        [singleContactDic setValue:firstName forKey:JSON_KEY_FIRST_NAME];
        [singleContactDic setValue:middleName forKey:JSON_KEY_MIDDLE_NAME];
        [singleContactDic setValue:lastName forKey:JSON_KEY_LAST_NAME];
        [singleContactDic setValue:fullName forKey:JSON_KEY_FULL_NAME];
        
        /* 取得多筆聯絡電話 */
        ABMultiValueRef phones = ABRecordCopyValue(ref,kABPersonPhoneProperty);
        NSMutableArray* phoneNumberArray = [[NSMutableArray alloc] init];
        for(CFIndex i = 0; i < ABMultiValueGetCount(phones); i++) {
            
            CFStringRef cfPhoneNumber = ABMultiValueCopyValueAtIndex(phones, i);
            NSString* phoneNumber = [NSString stringWithFormat:@"%@", (__bridge NSString*)cfPhoneNumber];
            [phoneNumberArray addObject:[self getStringWithOnlyDecimalDigit:phoneNumber]];
            CFRelease(cfPhoneNumber);
        }
        [singleContactDic setValue:phoneNumberArray forKey:JSON_KEY_PHONE];
        
        /* 取得多筆email */
        ABMultiValueRef emails = ABRecordCopyValue(ref, kABPersonEmailProperty);
        NSMutableArray* emailArray = [[NSMutableArray alloc] init];
        for (CFIndex i = 0; i < ABMultiValueGetCount(emails); i++) {
            CFStringRef cfEmail = ABMultiValueCopyValueAtIndex(emails, i);
            if(cfEmail == nil){
                continue;
            }
            NSString* email = [NSString stringWithFormat:@"%@", (__bridge NSString*)cfEmail];
            [emailArray addObject:email];
            CFRelease(cfEmail);
        }
        [singleContactDic setValue:emailArray forKey:JSON_KEY_MAIL];
        

        [singleContactDic setValue:[NSString stringWithFormat:@"%d",uid] forKey:JSON_KEY_UID];
        
        [allContactInfoArray addObject:singleContactDic];
    }
    
    return [self arrayToJson:allContactInfoArray];
}

/* iOS9以上使用CNContactStore */
- (NSString*)getContactDetailWithCNContact:(CNContactStore*)contactStore
{
    NSError* error = nil;
    NSMutableArray* allContactInfoArray = [[NSMutableArray alloc] init];
    CNContactFetchRequest* contactRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:@[CNContactPhoneNumbersKey,
                                                                                                 CNContactEmailAddressesKey,
                                                                                                 CNContactFamilyNameKey,
                                                                                                 CNContactMiddleNameKey,
                                                                                                 CNContactGivenNameKey,                                                                                               ]];
    [contactStore enumerateContactsWithFetchRequest:contactRequest error:&error usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
        
        NSMutableDictionary* singleContactDic = [[NSMutableDictionary alloc] init];
        /* 取得名字 */
        [singleContactDic setValue:contact.familyName forKey:JSON_KEY_FIRST_NAME];
        [singleContactDic setValue:contact.middleName forKey:JSON_KEY_MIDDLE_NAME];
        [singleContactDic setValue:contact.givenName forKey:JSON_KEY_LAST_NAME];
        
        //NSString* fullName = [CNContactFormatter stringFromContact:contact style:CNContactFormatterStyleFullName];
        //應該可用上方framework所提供的程式碼可取得全名，但發生未知錯誤導致crash，目前尚未查清原因
        NSString* fullName = @"";
        if ([contact.familyName length] > 0) { fullName = [NSString stringWithFormat:@"%@ ",contact.familyName];}
        if ([contact.middleName length] > 0) { fullName = [NSString stringWithFormat:@"%@%@ ",fullName,contact.middleName];}
        if ([contact.givenName length] > 0) { fullName = [NSString stringWithFormat:@"%@%@",fullName,contact.givenName];}
        [singleContactDic setValue:fullName forKey:JSON_KEY_FULL_NAME];
        [singleContactDic setValue: contact.identifier forKey:JSON_KEY_UID];
        
        /* 取得多筆聯絡電話 */
        NSMutableArray* phoneNumberArray = [[NSMutableArray alloc] init];
        for (CNLabeledValue* cnValue in contact.phoneNumbers) {
            if ([cnValue.label isEqualToString:CNLabelPhoneNumberiPhone]) {
                CNPhoneNumber* cnPhoneNumber = cnValue.value;
                [phoneNumberArray addObject:[self getStringWithOnlyDecimalDigit:cnPhoneNumber.stringValue]];
                
            } else if ([cnValue.label isEqualToString:CNLabelPhoneNumberMobile]) {
                CNPhoneNumber* cnPhoneNumber = cnValue.value;
                [phoneNumberArray addObject:[self getStringWithOnlyDecimalDigit:cnPhoneNumber.stringValue]];
                
            } else if ([cnValue.label isEqualToString:CNLabelPhoneNumberMain]) {
                CNPhoneNumber* cnPhoneNumber = cnValue.value;
                [phoneNumberArray addObject:[self getStringWithOnlyDecimalDigit:cnPhoneNumber.stringValue]];
            }
        }
        [singleContactDic setValue:phoneNumberArray forKey:JSON_KEY_PHONE];
        
        /* 取得多筆email */
        NSMutableArray* emailArray = [[NSMutableArray alloc] init];
        for (CNLabeledValue* cnValue in contact.emailAddresses) {
            NSString* email = cnValue.value;
            
            [emailArray addObject:email];
        }
        [singleContactDic setValue:emailArray forKey:JSON_KEY_MAIL];
        
        [allContactInfoArray addObject:singleContactDic];
    }];
    
    return [self arrayToJson:allContactInfoArray];
}

- (NSString*)arrayToJson:(NSMutableArray*)array
{
    if ([NSJSONSerialization isValidJSONObject:array]) {
        NSError* error = nil;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:array options:0 error:&error];  //一行模式
        
        if (jsonData != nil && error == nil) {
            NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            return jsonString;
            
        } else {
            NSLog(@"JSON encode error:%@",error);
        }
    } else {
        NSLog(@"not valid json object!");
    }
    return nil;
}

- (NSString*)getStringWithOnlyDecimalDigit:(NSString*)string
{
    NSString* phoneNumberString = [[string componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]] componentsJoinedByString:@""];
    
    return phoneNumberString;
}


@end
