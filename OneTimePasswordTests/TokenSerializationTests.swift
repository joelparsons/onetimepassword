//
//  TokenSerializationTests.swift
//  OneTimePassword
//
//  Created by Matt Rubin on 6/10/14.
//  Copyright (c) 2014 Matt Rubin. All rights reserved.
//

import XCTest
import OneTimePassword

extension Token {
    var url: NSURL {
        return NSURL(string: URLSerializer.serialize(self)!)!
    }
}

class TokenSerializationTests: XCTestCase {
    let kOTPScheme = "otpauth"
    let kOTPTokenTypeCounterHost = "hotp"
    let kOTPTokenTypeTimerHost   = "totp"

    let factors: [OneTimePassword.Generator.Factor] = [.Counter(0), .Counter(1), .Counter(UInt64.max),
                                                       .Timer(period: 1), .Timer(period: 30), .Timer(period: 300)]
    let names = ["", "Login", "user_123@website.com", "Léon", ":/?#[]@!$&'()*+,;=%\""]
    let issuers = ["", "Big Cörpøráçìôn", ":/?#[]@!$&'()*+,;=%\""]
    let secretStrings = ["12345678901234567890", "12345678901234567890123456789012", "1234567890123456789012345678901234567890123456789012345678901234", ""]
    let algorithms: [OneTimePassword.Generator.Algorithm] = [.SHA1, .SHA256, .SHA512]
    let digits = [6, 7, 8]

    func testSerialization() {
        for factor in factors {
            for name in names {
                for issuer in issuers {
                    for secretString in secretStrings {
                        for algorithm in algorithms {
                            for digitNumber in digits {
                                // Create the token
                                let generator = Generator(
                                    factor: factor,
                                    secret: secretString.dataUsingEncoding(NSASCIIStringEncoding)!,
                                    algorithm: algorithm,
                                    digits: digitNumber
                                )
                                XCTAssert(generator != nil)

                                if let generator = generator {
                                    let token = Token(
                                        name: name,
                                        issuer: issuer,
                                        core: generator
                                    )

                                    // Serialize
                                    let url = token.url

                                    // Test scheme
                                    XCTAssertEqual(url.scheme!, kOTPScheme, "The url scheme should be \"\(kOTPScheme)\"")
                                    // Test Factor
                                    var expectedHost: String
                                    switch factor {
                                    case .Counter:
                                        expectedHost = kOTPTokenTypeCounterHost
                                    case .Timer:
                                        expectedHost = kOTPTokenTypeTimerHost
                                    }
                                    XCTAssertEqual(url.host!, expectedHost, "The url host should be \"\(expectedHost)\"")
                                    // Test name
                                    XCTAssertEqual(url.path!.substringFromIndex(url.path!.startIndex.successor()), name, "The url path should be \"\(name)\"")

                                    var urlComponents = NSURLComponents(URL:url, resolvingAgainstBaseURL:false)
                                    var items = urlComponents?.queryItems as! [NSURLQueryItem]
                                    let expectedItemCount = 4
                                    XCTAssertEqual(items.count, expectedItemCount, "There shouldn't be any unexpected query arguments: \(url)")

                                    var queryArguments = Dictionary<String, String>()
                                    for item in items {
                                        queryArguments[item.name] = item.value
                                    }
                                    XCTAssertEqual(queryArguments.count, expectedItemCount, "There shouldn't be any unexpected query arguments: \(url)")

                                    // Test algorithm
                                    let algorithmString: String = {
                                        switch $0 {
                                        case .SHA1:   return "SHA1"
                                        case .SHA256: return "SHA256"
                                        case .SHA512: return "SHA512"
                                        }}(algorithm)
                                    XCTAssertEqual(queryArguments["algorithm"]!, algorithmString, "The algorithm value should be \"\(algorithmString)\"")
                                    // Test digits
                                    XCTAssertEqual(queryArguments["digits"]!, String(digitNumber), "The digits value should be \"\(digitNumber)\"")
                                    // Test secret
                                    XCTAssertNil(queryArguments["secret"], "The url query string should not contain the secret")

                                    // Test period
                                    switch factor {
                                    case .Timer(let period):
                                        XCTAssertEqual(queryArguments["period"]!, String(Int(period)), "The period value should be \"\(period)\"")
                                    default:
                                        XCTAssertNil(queryArguments["period"], "The url query string should not contain the period")
                                    }
                                    // Test counter
                                    switch factor {
                                    case .Counter(let counter):
                                        XCTAssertEqual(queryArguments["counter"]!, String(counter), "The counter value should be \"\(counter)\"")
                                    default:
                                        XCTAssertNil(queryArguments["counter"], "The url query string should not contain the counter")
                                    }

                                    // Test issuer
                                    XCTAssertEqual(queryArguments["issuer"]!, issuer, "The issuer value should be \"\(issuer)\"")

                                    // Check url again
                                    let checkURL = token.url
                                    XCTAssertEqual(url, checkURL, "Repeated calls to url() should return the same result!")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
