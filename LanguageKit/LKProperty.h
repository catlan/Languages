#import <LanguageKit/LKAST.h>

@class LKToken;

@interface LKProperty : LKAST {
    LKToken *variableName;
}
+ (instancetype) propertyDeclWithName:(LKToken*) declName;
- (NSString*)name;
@end

