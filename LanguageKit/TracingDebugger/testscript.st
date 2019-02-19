NSObject extend [
    doAThing [
        | greeting object |
        greeting := 'Hello'.
        object := 'world'.
        ^greeting stringByAppendingString:object.
    ]
]
