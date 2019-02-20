//
//  LKVariableDescription.h
//  LanguageKit
//
//  Created by Graham Lee on 20/02/2019.
//

#import <Foundation/Foundation.h>

@class LKSymbol;

/**
 * A description of a variable to be presented by a debugger or monitor.
 * An LKVariableDescription names the variable, gives its type and value,
 * and tells you something of the scope from which it came.
 */
@interface LKVariableDescription : NSObject

/**
 * The symbol defining this variable. This collects the name,
 * the scope, the defining node in the AST, and the type.
 */
@property (readonly) LKSymbol *symbol;
/**
 * The value of the variable. If the variable represents an object
 * (in other words, if its type is "@"), then the value is just that
 * object. Otherwise, the value is wrapped in an NSValue.
 */
@property (readonly) id value;

/**
 * Create a variable description holding a particular value for a given symbol.
 */
- (instancetype)initWithSymbol: (LKSymbol *)aSymbol value: (id)aValue;

@end
