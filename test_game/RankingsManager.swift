import Foundation
import FirebaseAuth
import FirebaseFirestore

public struct RankingEntry: Codable {
    public let uid: String
    public let name: String?
    public let score: Int
    public let timestamp: Date
    public let difficulty: Int? // 難易度（秒数）
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

    // Submit score: uses composite key (uid + difficulty) to keep separate records per difficulty
    func submitScore(_ score: Int, difficulty: Int, name: String? = nil, completion: ((Error?)->Void)? = nil) {
        guard let user = Auth.auth().currentUser else {
            completion?(NSError(domain: "Rankings", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]))
            return
        }
        let uid = user.uid
        let docId = "\(uid)_\(difficulty)" // 難易度別にドキュメントを分ける
        let docRef = db.collection("rankings").document(docId)
        let data: [String: Any] = [
            "uid": uid,
            "name": name ?? NSNull(),
            "score": score,
            "difficulty": difficulty,
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

    func fetchTop(difficulty: Int, limit: Int = 10, completion: @escaping ([RankingEntry]?, Error?)->Void) {
        // インデックス不要のクエリ：difficultyでフィルタリングのみ
        db.collection("rankings")
            .whereField("difficulty", isEqualTo: difficulty)
            .getDocuments { snapshot, error in
                if let err = error {
                    completion(nil, err)
                    return
                }
                guard let docs = snapshot?.documents else {
                    completion([], nil)
                    return
                }
                var entries: [RankingEntry] = docs.compactMap { doc in
                    let uid = doc.get("uid") as? String ?? doc.documentID
                    let name = doc.get("name") as? String
                    let score = doc.get("score") as? Int ?? 0
                    let difficulty = doc.get("difficulty") as? Int
                    let ts = (doc.get("timestamp") as? Timestamp)?.dateValue() ?? Date()
                    return RankingEntry(uid: uid, name: name, score: score, timestamp: ts, difficulty: difficulty)
                }
                // クライアント側でソートとリミット
                entries.sort { $0.score > $1.score }
                if entries.count > limit {
                    entries = Array(entries.prefix(limit))
                }
                completion(entries, nil)
            }
    }
}
