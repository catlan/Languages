#import "NSArray+map.h"
#import "BlockClosure.h"
#import <EtoileFoundation/EtoileFoundation.h>

@implementation NSArray (map)
- (NSArray*) map:(id)aClosure
{
	id new[[self count]];
	int i = 0;
    for (id obj in self)
	{
		new[i] = [aClosure value:obj];
		i++;
	}
	return [NSArray arrayWithObjects:new count:i];
}

- (NSArray*) flatMap:(id)aClosure
{
    NSMutableArray *array = [NSMutableArray array];
    for (id obj in self)
    {
        NSArray *returnedArray = [aClosure value:obj];
        if ([returnedArray count])
        {
            [array addObjectsFromArray:returnedArray];
        }
    }
    return [array copy];
}

- (void) foreach:(id)aClosure
{
    for (id obj in self)
	{
		[aClosure value:obj];
	}
}
- (void) do:(id)aClosure
{
    for (id obj in self)
	{
		[aClosure value:obj];
	}
}
- (NSArray*) select:(id)aClosure
{
	id new[[self count]];
	int i = 0;
    for (id obj in self)
	{
		if ([[aClosure value:obj] boolValue])
		{
			new[i++] = obj;
		}
	}
	return [NSArray arrayWithObjects:new count:i];
}
- (id) detect:(id)aClosure
{
	id new[[self count]];
	int i = 0;
    for (id obj in self)
	{
		if ([[aClosure value:obj] boolValue])
		{
			return obj;
		}
	}
	return nil;
}
- (id) inject:(id)aValue into:aClosure
{
	id collect = aValue;
    for (id obj in self) 
	{
		collect = [aClosure value:obj value:collect];
	}
	return collect;
}
- (id) fold:(id)aClosure
{
	return [self inject:nil into:aClosure];
}
@end
