import Foundation
import FirebaseAuth
import FirebaseFirestore

public struct RankingEntry: Codable {
    public let uid: String
    public let name: String?
    public let score: Int
    public let timestamp: Date
}

final class RankingsManager {
    static let shared = RankingsManager()
    private init() {}

    private var db: Firestore {
        return Firestore.firestore()
    }

    func setup(completion: ((Error?)->Void)? = nil) {
        // Ensure anonymous sign-in
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { _, error in
                completion?(error)
            }
        } else {
            completion?(nil)
        }
    }

    // Submit score: uses uid as document id to keep one record per user
    func submitScore(_ score: Int, name: String? = nil, completion: ((Error?)->Void)? = nil) {
        guard let user = Auth.auth().currentUser else {
            completion?(NSError(domain: "Rankings", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]))
            return
        }
        let uid = user.uid
        let docRef = db.collection("rankings").document(uid)
        let data: [String: Any] = [
            "uid": uid,
            "name": name ?? NSNull(),
            "score": score,
            "timestamp": FieldValue.serverTimestamp()
        ]

        // Transactional update: only update if new score is higher
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let snapshot = try transaction.getDocument(docRef)
                if snapshot.exists, let existing = snapshot.get("score") as? Int {
                    if score <= existing {
                        // no update required
                        return nil
                    }
                }
                transaction.setData(data, forDocument: docRef, merge: true)
            } catch let e as NSError {
                errorPointer?.pointee = e
                return nil
            }
            return nil
        }) { (_, error) in
            completion?(error)
        }
    }

    func fetchTop(limit: Int = 10, completion: @escaping ([RankingEntry]?, Error?)->Void) {
        db.collection("rankings")
            .order(by: "score", descending: true)
            .limit(to: limit)
            .getDocuments { snapshot, error in
                if let err = error {
                    completion(nil, err)
                    return
                }
                guard let docs = snapshot?.documents else {
                    completion([], nil)
                    return
                }
                let entries: [RankingEntry] = docs.compactMap { doc in
                    let uid = doc.get("uid") as? String ?? doc.documentID
                    let name = doc.get("name") as? String
                    let score = doc.get("score") as? Int ?? 0
                    let ts = (doc.get("timestamp") as? Timestamp)?.dateValue() ?? Date()
                    return RankingEntry(uid: uid, name: name, score: score, timestamp: ts)
                }
                completion(entries, nil)
            }
    }
}
