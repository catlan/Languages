NSObject extend [
    doAThing [
        | greeting object |
        greeting := 'Hello'.
        object := [ | foo |
            foo := ' world'.
            foo := greeting stringByAppendingString: foo.
            ^ foo. ] value.
        ^object.
    ]
]
