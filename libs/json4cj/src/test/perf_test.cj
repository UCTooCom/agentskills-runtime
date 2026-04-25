package json4cj.test

import std.unittest.testmacro.{Test, TestCase, Expect, Skip}
import std.random.Random
internal import stdx.encoding.json.stream.*
import json4cj.{JsonCodec, JsonValueSerializable}
import json4cj.jsonmacro.{JsonSerialize}
import json4cj.*

@JsonSerialize
class MovieDatabase {
    var movies: ArrayList<Movie> = ArrayList<Movie>()

    public static func generateSample(): MovieDatabase {
        let movieCount = 100
        let reviewCount = 100
        let random = Random()

        let db = MovieDatabase()
        for (i in 0..movieCount) {
            let movie = Movie()
            movie.id = i
            movie.name = "MovieName-${i}"

            for (k in 0..reviewCount) {
                let review = Review()
                review.id = k
                review.title = "review-${k}"
                review.score = random.nextInt64(100)
                review.content = MovieDatabase.generateMovieReview()
                movie.reviews.add(review)
            }
            db.movies.add(movie)
        }

        return db
    }

    public static func generateMovieReview(): String {
        let random = Random()

        let positiveAdjectives = ["amazing", "fantastic", "brilliant", "captivating", "engaging", "incredible",
            "spectacular", "thrilling", "heartwarming", "unforgettable"]
        let negativeAdjectives = ["terrible", "boring", "disappointing", "dull", "unimpressive", "mediocre",
            "predictable", "confusing", "awful", "atrocious"]
        let movieAspects = ["plot", "acting", "cinematography", "soundtrack", "special effects", "script", "characters",
            "directing"]
        let positiveStarters = ["I was completely blown away by", "This movie is an absolute gem with",
            "The moment I started watching, I knew it was going to be amazing because of"]
        let negativeStarters = ["I had high hopes for this movie, but it turned out to be",
            "Sadly, this movie failed to deliver with", "What a disappointment! The"]

        if (random.nextInt64(100) < 50) {
            let starter = positiveStarters[random.nextInt64(100) % positiveStarters.size];
            let adjective = positiveAdjectives[random.nextInt64(100) % positiveAdjectives.size];
            let aspect = movieAspects[random.nextInt64(100) % movieAspects.size];
            return "${starter} its ${adjective} ${aspect}. The whole movie kept me on the edge of my seat from start to finish. The performances were top-notch and the story was engaging. I highly recommend it!"
        } else {
            let starter = negativeStarters[random.nextInt64(100) % negativeStarters.size];
            let adjective = negativeAdjectives[random.nextInt64(100) % negativeAdjectives.size];
            let aspect = movieAspects[random.nextInt64(100) % movieAspects.size];
            return "${starter} ${adjective} ${adjective} ${aspect}. It felt like a waste of time. The characters were unconvincing and the plot was all over the place. I wouldn't recommend it to anyone."
        }
    }
}

@JsonSerialize
class Movie {
    var id: Int64 = 0
    var name: String = "Name"
    var year: Int64 = 2000
    var reviews: ArrayList<Review> = ArrayList<Review>()
}

@JsonSerialize
class Review {
    var id: Int64 = 0
    var title: String = "title"
    var score: Int64 = 90
    var content: String = "content"
}

@Test
class TestPerf {
    private var movieDataBase = MovieDatabase.generateSample()

    @Skip
    @TestCase
    func testPerf(): Unit {
        let db2 = MovieDatabase.fromJson(movieDataBase.toJson())
        @Expect(true)
    }
}
