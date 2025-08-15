import Foundation
import CryptoKit

// MARK: - Encryption Manager
class EncryptionManager {
    private static let encryptionKey: String = Secrets.encryptionKey
    
    static func getSymmetricKey() throws -> SymmetricKey {
        guard let keyData = Data(base64Encoded: encryptionKey) else {
            throw EncryptionError.invalidKey
        }
        return SymmetricKey(data: keyData)
    }
    
    static func encrypt<T: Codable>(_ object: T) throws -> EncryptedData {
        let key = try getSymmetricKey()
        
        // Convert object to JSON data
        let jsonData = try JSONEncoder().encode(object)
        
        // Encrypt the data
        let sealedBox = try AES.GCM.seal(jsonData, using: key)
        
        // Extract components
        guard let combinedData = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return EncryptedData(
            data: combinedData.base64EncodedString(),
            algorithm: "AES-256-GCM"
        )
    }
    
    static func decrypt<T: Codable>(_ encryptedData: EncryptedData, as type: T.Type) throws -> T {
        let key = try getSymmetricKey()
        
        // Decode the encrypted data
        guard let combinedData = Data(base64Encoded: encryptedData.data) else {
            throw EncryptionError.invalidData
        }
        
        // Create sealed box and decrypt
        let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        // Decode back to object
        let object = try JSONDecoder().decode(type, from: decryptedData)
        return object
    }
}

// MARK: - Supporting Types
struct EncryptedData: Codable {
    let data: String      // Base64 encoded encrypted data
    let algorithm: String // "AES-256-GCM"
}

enum EncryptionError: Error, LocalizedError {
    case invalidKey
    case encryptionFailed
    case decryptionFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid encryption key"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidData:
            return "Invalid encrypted data format"
        }
    }
}

// MARK: - Updated BankAccount with Encryption Support
extension BankAccount {
    func encrypt() throws -> EncryptedData {
        return try EncryptionManager.encrypt(self)
    }
    
    static func decrypt(from encryptedData: EncryptedData) throws -> BankAccount {
        return try EncryptionManager.decrypt(encryptedData, as: BankAccount.self)
    }
}

// MARK: - Test the Encryption
extension EncryptionManager {
    static func testEncryption() {
        print("🔐 Testing Encryption System...")
        
        // Create a test bank account
        let testBankAccount = BankAccount(
            accountHolderName: "John Doe",
            bankName: "Test Bank",
            accountNumber: "1234567890",
            routingNumber: "123456789",
            accountType: "checking",
            addressLine1: "123 Main St",
            city: "New York",
            state: "NY",
            zipCode: "10001"
        )
        
        do {
            // Test encryption
            let encrypted = try testBankAccount.encrypt()
            print("✅ Encryption successful")
            print("   Encrypted data preview: \(encrypted.data.prefix(20))...")
            
            // Test decryption
            let decrypted = try BankAccount.decrypt(from: encrypted)
            print("✅ Decryption successful")
            print("   Account holder: \(decrypted.accountHolderName)")
            print("   Bank: \(decrypted.bankName)")
            print("   Account: ****\(decrypted.accountNumber.suffix(4))")
            
            // Verify data integrity
            if testBankAccount.accountHolderName == decrypted.accountHolderName &&
               testBankAccount.accountNumber == decrypted.accountNumber {
                print("✅ Data integrity verified - encryption/decryption working perfectly!")
            } else {
                print("❌ Data integrity failed")
            }
            
        } catch {
            print("❌ Encryption test failed: \(error)")
        }
    }
}
