//
//  PokemonSearchService.swift
//  Wefox Pokedex
//
//  Created by Ronan on 09/05/2019.
//  Copyright © 2019 Sonomos. All rights reserved.
//

import Foundation

import Moya
import Result
import Combine
import PokedexCommon

protocol PokemonSearchLoadingService: class {
    var provider: MoyaProvider<PokemonSearchEndpoint> { get }
    
    func search(identifier: Int, completion: @escaping (_ data: Data?, _ error: String?) -> Void)
}

class PokemonSearchService: PokemonSearchLoadingService {
    // swiftlint:disable force_unwrapping
    let customEndpointClosure = { (target: PokemonSearchEndpoint) -> Endpoint in
        return Endpoint(url: URL(target: target).absoluteString,
                        sampleResponseClosure: { .networkResponse(401, "Not authorized".data(using: .utf8)!) },
                        method: target.method,
                        task: target.task,
                        httpHeaderFields: target.headers)
    }
    
    private var cancellable: AnyCancellable?
    
    var provider: MoyaProvider<PokemonSearchEndpoint> {
        
        if Configuration.authenticationErrorTesting {
            return MoyaProvider<PokemonSearchEndpoint>(endpointClosure: customEndpointClosure, stubClosure: MoyaProvider.immediatelyStub)
        } else if Configuration.uiTesting == true {
            return MoyaProvider<PokemonSearchEndpoint>(stubClosure: MoyaProvider.immediatelyStub)
        } else if Configuration.networkTesting {
            return MoyaProvider<PokemonSearchEndpoint>(plugins: [NetworkLoggerPlugin()])
        } else {
            return MoyaProvider<PokemonSearchEndpoint>(callbackQueue: DispatchQueue.global(qos: .background))
        }
    }
    
    func search(identifier: Int, completion: @escaping (_ data: Data?, _ error: String?) -> Void) {
        provider.request(.search(identifier: identifier)) { result in
            switch result {
            case .success(let response):
                if response.statusCode == 404 {
                    completion(nil, Constants.Translations.Error.statusCode404)
                    return
                }
                
                if 200 ..< 300 ~= response.statusCode {
                    completion(response.data, nil)
                } else {
                    completion(nil, "Error: \(response.statusCode)")
                }
            case .failure(let error):
                completion(nil, error.localizedDescription)
            }
        }
    }
    
    enum HTTPError: LocalizedError {
        case statusCode
        case urlRequestError
    }
    
//    func search(identifier: Int) -> AnyPublisher<Data, Error> {
//        // TODO: Improve this mapping of the URL to a request
//        let target = PokemonSearchEndpoint.search(identifier: identifier)
//        let provider = MoyaProvider<PokemonSearchEndpoint>()
//        let endpoint = provider.endpoint(target)
//
//        do {
//            let urlRequest = try endpoint.urlRequest()
//            return load(urlRequest: urlRequest)
//        } catch {
//            return Fail(error: HTTPError.urlRequestError).eraseToAnyPublisher()
//        }
//    }
    
    func search(identifier: Int) -> AnyPublisher<Pokemon, Error> {
        // TODO: Improve this mapping of the URL to a request
        let target = PokemonSearchEndpoint.search(identifier: identifier)
        let provider = MoyaProvider<PokemonSearchEndpoint>()
        let endpoint = provider.endpoint(target)
        
        do {
            let urlRequest = try endpoint.urlRequest()
            return load(urlRequest: urlRequest)
        } catch {
            return Fail(error: HTTPError.urlRequestError).eraseToAnyPublisher()
        }
    }
    
    func load(urlRequest: URLRequest) -> AnyPublisher<Data, Error> {
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .validateStatusCode({ (200..<300).contains($0) })
            .mapError { $0 as Error }
            .map { $0.data }
            .eraseToAnyPublisher()
    }
    
    func load(urlRequest: URLRequest) -> AnyPublisher<Pokemon, Error> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            //.validateStatusCode({ (200..<300).contains($0) })
            .mapError { $0 as Error }
            .map { $0.data }
            .decode(type: Pokemon.self, decoder: decoder)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func load(url: URL) -> AnyPublisher<Data, Error> {
           return URLSession.shared.dataTaskPublisher(for: url)
            .validateStatusCode({ (200..<300).contains($0) })
            .mapError { $0 as Error }
            .map { $0.data }
            .eraseToAnyPublisher()
    }
    
    func loadSamplePokemon() {
        let url1 = URL(string: "https://pokeapi.co/api/v2/pokemon/182/")!
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url1)
            .validateStatusCode({ (200..<300).contains($0) })
            .map { $0.data }
            .decode(type: Pokemon.self, decoder: decoder)
            .sink(receiveCompletion: { (error) in
                print("Error: \(error)")
            }) { (pokemon) in
                print("Pokemon found with name: \(pokemon.name)")
            }
    }
}

enum ValidationError: Error {
    case error(Error)
    case jsonError(Data)
}

typealias DataTaskResult = (data: Data, response: URLResponse)

extension Publisher where Output == DataTaskResult {
    func validateStatusCode(_ isValid: @escaping (Int) -> Bool) -> AnyPublisher<Output, ValidationError> {
        return validateResponse { (data, response) in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            return isValid(statusCode)
        }
    }
    
    func validateResponse(_ isValid: @escaping (DataTaskResult) -> Bool) -> AnyPublisher<Output, ValidationError> {
        return self
            .mapError { .error($0) }
            .flatMap { (result) -> AnyPublisher<DataTaskResult, ValidationError> in
                let (data, _) = result
                if isValid(result) {
                    return Just(result)
                        .setFailureType(to: ValidationError.self)
                        .eraseToAnyPublisher()
                } else {
                    return Fail(outputType: Output.self, failure: .jsonError(data))
                        .eraseToAnyPublisher()
                }}
            .eraseToAnyPublisher()
    }
}
