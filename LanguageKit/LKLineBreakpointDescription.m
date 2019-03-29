//
//  LKLineBreakpointDescription.m
//  LanguageKit
//
//  Created by Graham Lee on 18/03/2019.
//

#import "LKLineBreakpointDescription.h"

@implementation LKLineBreakpointDescription

- (instancetype)initWithFile:(NSString *)file line:(NSUInteger)line
{
    self = [super init];
    if (!self) return nil;
    _file = [file copy];
    _line = line;
    return self;
}

- (BOOL)isEqual:(id)object
{
    if ([object isMemberOfClass:[LKLineBreakpointDescription class]]) {
        return [_file isEqual:[object file]] && _line == [object line];
    } else {
        return NO;
    }
}

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(nonnull NSCoder *)aCoder {
    [aCoder encodeObject:_file forKey:@"file"];
    [aCoder encodeObject:@(_line) forKey:@"line"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)aDecoder {
    NSString *file = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"file"];
    NSNumber *line = [aDecoder decodeObjectOfClass:[NSNumber class] forKey:@"line"];
    return [self initWithFile:file line:[line unsignedIntegerValue]];
}

@end
