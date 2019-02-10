
SmalltalkTests extend [

     classMethodInvocation [
        SmalltalkTests show: 'class method invocation [SmalltalkTests show:]'.
        self class show: 'class method invocation [self class show:]'.
     ]

     pie [
        ^ 3.141592653589793238.
     ]

     negativeOne [
        ^ -1.
     ]

     negativeOnePointTwoThree [
        ^ -1.23.
     ]

	 arrayLiterals [
		^ {1. 2. 3}.
	 ]

     onePlusTwo [
        ^ 1 + 2.
     ]

     threePlusFourTimesFive [
        ^ 3 + 4 * 5.
     ]

     fourThirdsTimesThreeEqualsFour [
        ^ (10 / 3) * 3 == 4.
     ]

     stringForIfNil [
        | testVar rtn |
        rtn := 'test is NOT nil'.
        testVar ifNil: [ rtn := 'test is nil'. ].
        ^ rtn.
     ]

     stringForIfNilIfNotNilBranch1 [
        | testVar rtn |
        rtn := ''.
        testVar ifNil: [ rtn := 'test is nil'. ] ifNotNil: [ rtn := 'test is NOT nil'. ].
        ^ rtn.
     ]

     stringForIfNilIfNotNilBranch2 [
        | testVar rtn |
        rtn := ''.
        rtn ifNil: [ rtn := 'test is nil'. ] ifNotNil: [ rtn := 'test is NOT nil'. ].
        ^ rtn.
     ]

     stringForIfNotNil [
        | testVar rtn |
        rtn := 'test is nil'.
        rtn ifNotNil: [ rtn := 'test is NOT nil'. ].
        ^ rtn.
     ]

     stringForIfNotNilIfNilBranch1 [
        | testVar rtn |
        rtn := ''.
        rtn ifNotNil: [ rtn := 'test is NOT nil'. ] ifNil: [ rtn := 'test is nil'. ].
        ^ rtn.
     ]

     stringForIfNotNilIfNilBranch2 [
        | testVar rtn |
        rtn := ''.
        testVar ifNotNil: [ rtn := 'test is NOT nil'. ] ifNil: [ rtn := 'test is nil'. ].
        ^ rtn.
     ]

]

NSObject subclass: SmalltalkSubclassTests [
    | var1 |

    init [
        var1 := 'Hello'.
        ^self
    ]

    var1 [
        ^var1
    ]

]

SmalltalkSubclassTests subclass: SmalltalkSubSubclassTests [
    | var2 |

    init [
        super init.
        var2 := 'World'.
        ^self
    ]

    var2 [
        ^var2
    ]
]
