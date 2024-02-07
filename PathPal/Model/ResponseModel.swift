//
//  ResponseModel.swift
//  PathPal
//
//  Created by Suji Lee on 2/7/24.
//

struct ResponseModel: Codable {
    var koreanTTSString: String = ""
    var englishTTSString: String?
    var needAlert: String = ""
}
