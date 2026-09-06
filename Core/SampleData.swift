import Foundation

public enum SampleData {
    public static func makeTrip(now: Date = Date()) -> Trip {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let firstDay = calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: now))!
        func moment(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: day, to: firstDay)!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
        }
        return Trip(title: "京都、余白を楽しむ旅", destination: "京都・東山・嵐山",
                    startDate: firstDay, endDate: moment(2, 0), budget: 65000,
                    notes: "サンプルの旅行です。時刻・便名・金額・予約番号は架空の例で、実際の運行や予約を示すものではありません。予定を編集して、自分だけの旅にしましょう。",
                    items: [
                        ItineraryItem(title: "京都へ、新幹線の旅", kind: .train,
                            startDate: moment(0, 9), endDate: moment(0, 11, 15),
                            departure: "東京駅", arrival: "京都駅", serviceNumber: "のぞみ（サンプル）",
                            reservationCode: "SAMPLE-TRAIN", notes: "乗車前に駅で朝ごはん。座席・乗り場を確認する。",
                            cost: 14000, location: Place(name: "京都駅", address: "京都府京都市下京区東塩小路釜殿町", latitude: 34.9858, longitude: 135.7588)),
                        ItineraryItem(title: "祇園でゆっくりランチ", kind: .restaurant,
                            startDate: moment(0, 12, 30), endDate: moment(0, 13, 30),
                            notes: "お店は未定。京野菜のランチを探したい。金額は目安。", cost: 2500,
                            location: Place(name: "祇園エリア", address: "京都府京都市東山区祇園町", latitude: 35.0031, longitude: 135.7780)),
                        ItineraryItem(title: "清水寺と坂道さんぽ", kind: .activity,
                            startDate: moment(0, 14, 30), endDate: moment(0, 16), notes: "歩きやすい靴で。拝観時間は出発前に確認。", cost: 500,
                            location: Place(name: "清水寺", address: "京都府京都市東山区清水1丁目294", latitude: 34.9949, longitude: 135.7850)),
                        ItineraryItem(title: "ホテルにチェックイン", kind: .hotel,
                            startDate: moment(0, 17), reservationCode: "SAMPLE-HOTEL",
                            notes: "サンプルの宿泊予定。2泊分の予算。ホテル名・住所・予約書類を追加しましょう。", cost: 24000),
                        ItineraryItem(title: "嵐山へ移動", kind: .train,
                            startDate: moment(1, 9), endDate: moment(1, 9, 30),
                            departure: "京都駅", arrival: "嵯峨嵐山駅", serviceNumber: "JR嵯峨野線（サンプル）", cost: 250,
                            location: Place(name: "嵯峨嵐山駅", address: "京都府京都市右京区嵯峨天龍寺車道町", latitude: 35.0188, longitude: 135.6812)),
                        ItineraryItem(title: "竹林を歩く", kind: .activity,
                            startDate: moment(1, 10), endDate: moment(1, 11, 30), notes: "カメラの充電を忘れずに。",
                            location: Place(name: "嵐山 竹林の小径", address: "京都府京都市右京区嵯峨小倉山田淵山町", latitude: 35.0174, longitude: 135.6713)),
                        ItineraryItem(title: "川沿いのカフェでひと休み", kind: .restaurant,
                            startDate: moment(1, 12), endDate: moment(1, 13), notes: "お店は現地で決める。テラス席があればうれしい。", cost: 1800,
                            location: Place(name: "渡月橋エリア", address: "京都府京都市右京区嵯峨中ノ島町", latitude: 35.0134, longitude: 135.6779)),
                        ItineraryItem(title: "駅へ戻るバス", kind: .bus,
                            startDate: moment(2, 13), endDate: moment(2, 13, 30),
                            departure: "市内の宿泊先付近", arrival: "京都駅", serviceNumber: "路線未定（サンプル）",
                            notes: "停留所・系統・時刻は出発前に確認する。", cost: 230,
                            location: Place(name: "京都駅", address: "京都府京都市下京区", latitude: 34.9858, longitude: 135.7588)),
                        ItineraryItem(title: "おみやげを買って東京へ", kind: .train,
                            startDate: moment(2, 15), endDate: moment(2, 17, 15),
                            departure: "京都駅", arrival: "東京駅", serviceNumber: "のぞみ（サンプル）", cost: 14000)
                    ], checklist: [
                        ChecklistItem(title: "交通・宿泊の予約を確認"),
                        ChecklistItem(title: "チケット・予約PDFを保存"),
                        ChecklistItem(title: "充電器"),
                        ChecklistItem(title: "モバイルバッテリー"),
                        ChecklistItem(title: "身分証・保険証"),
                        ChecklistItem(title: "天気予報と歩きやすい靴")
                    ], createdAt: now)
    }
}
