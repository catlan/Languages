//
//  LKVariableDescription.m
//  LanguageKit
//
//  Created by Graham Lee on 20/02/2019.
//

#import "LKVariableDescription.h"
#import "LKSymbolTable.h"

static NSString *LKScopeDescription(LKSymbol *symbol) {
    switch (symbol.scope) {
        case LKSymbolScopeClass:
            return @"class";
            break;
        case LKSymbolScopeLocal:
            return @"local";
            break;
        case LKSymbolScopeGlobal:
            return @"global";
            break;
        case LKSymbolScopeObject:
            return @"object";
            break;
        case LKSymbolScopeInvalid:
            return @"invalid scope";
            break;
        case LKSymbolScopeArgument:
            return @"argument";
            break;
        case LKSymbolScopeExternal:
            return @"external";
            break;
        default:
            return @"unknown scope";
            break;
    }
}
@implementation LKVariableDescription

- (instancetype)initWithSymbol:(LKSymbol *)aSymbol value:(id)aValue {
    self = [super init];
    if (self) {
        _symbol = aSymbol;
        _value = [aValue copy];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ (%@): %@", [_symbol name], LKScopeDescription(_symbol), _value];
}

@end
