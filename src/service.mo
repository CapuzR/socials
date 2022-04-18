import Types "./types";
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Rels "./Rels/Rels";
import Source "mo:uuid/async/SourceV4";
import UUID "mo:uuid/UUID";
import Utils "./utils";

actor Self {

//Types
    type Error = Types.Error;
    type PostCreate = Types.PostCreate;
    type PostUpdate = Types.PostUpdate;
    type Post = Types.Post;
    type PostRead = Types.PostRead;
    type GalleryCreate = Types.GalleryCreate;
    type GalleryUpdate = Types.GalleryUpdate;
    type Gallery = Types.Gallery;
    type Suggestion = Types.Suggestion;
    type SuggestionCreate = Types.SuggestionCreate;
    type SuggestionUpdate = Types.SuggestionUpdate;
    type Comment = Types.Comment;
    type AllComments = Types.AllComments;
    type CommentCreate = Types.CommentCreate;
    type CommentUpdate = Types.CommentUpdate;

//State
    //Aquí se debe agregar el canisterId del ArtistRegistry
    stable var authorized : [Principal] = [];

    stable var posts : Trie.Trie<Text, Post> = Trie.empty();//postId,Post
    
    stable var galleries : Trie.Trie<Text, Gallery> = Trie.empty();//postId,Gallery

    stable var likes : [(Text, Principal)] = [];//postId|commentId|suggestionCommentId,artistPrincipal
    let likesRels = Rels.Rels<Text, Principal>((Text.hash, Principal.hash), (Text.equal, Principal.equal), likes);

    stable var follows : [(Principal, Principal)] = [];//artistPrincipal,followerPrincipal
    let followsRels = Rels.Rels<Principal, Principal>((Principal.hash, Principal.hash), (Principal.equal, Principal.equal), follows);
    
    stable var principalUsername : [(Principal, Text)] = [];//artistPrincipal,followerPrincipal
    let principalUsernameRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), principalUsername);
    
    stable var postSuggestions : [(Text,Text)] = [];//postId,suggestionCommentId
    let postSuggestionsRels = Rels.Rels<Text, Text>((Text.hash, Text.hash), (Text.equal, Text.equal), postSuggestions);
    
    stable var artistSuggestions : [(Principal,Text)] = [];//artistPrincipal,suggestionId
    let artistSuggestionsRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), artistSuggestions);
    
    stable var suggestions : Trie.Trie<Text, Suggestion> = Trie.empty();//suggestionId,Suggestion

    stable var comments : Trie.Trie2D<Text, Text, Comment> = Trie.empty(); //postId|commentId|suggestionId,(commentId|suggestionCommentId,comment)

    stable var artistPosts : [(Principal, Text)] = []; //artistPrincipal,postId
    let artistPostsRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), artistPosts); //artistPrincipal,postId

    stable var artistComments : [(Principal, Text)] = [];//artistPrincipal,commentId
    let artistCommentsRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), artistComments);

    stable var artGalleries : [(Principal, Text)] = [];//artistPrincipal,postId
    let artGalleriesRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), artGalleries);

    stable var galleryPost : [(Text,Text)] = [];
    let galleryPostRels = Rels.Rels<Text, Text>((Text.hash, Text.hash), (Text.equal, Text.equal), galleryPost);
    
    stable var artistGalleries : [(Principal,Text)] = [];
    let artistGalleriesRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), artistGalleries);
    
//---------------Public

//Post
    public shared({caller}) func createPost (postData : PostCreate) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let g = Source.Source();
        let postId = Text.concat("P", UUID.toText(await g.new()));

        let post : Post = {
            createdAt = Time.now();
            postBasics = postData.postBasics;
        };

        let (newPosts, existing) = Trie.put(
            posts,
            Utils.keyText(postId),
            Text.equal,
            post
        );

        switch(existing) {
            case null {
                posts := newPosts;
                artistPostsRels.put(caller, postId);
                #ok(());
            };
            case (? v) {
                await createPost(postData);
            };
        };
    };

    public query({caller}) func readPostById (postId : Text) : async Result.Result<PostRead, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let targetPost = Trie.find(
            posts, 
            Utils.keyText(postId),
            Text.equal
        );

        switch(targetPost) {
            case null {
                #err(#Unknown("Post doesn't exist."));
            };
            case (? post) {
                
                let targetComments = Trie.find(
                    comments, 
                    Utils.keyText(postId),
                    Text.equal
                );

                switch(targetComments) {
                    case null {
                        #err(#Unknown("Target doesn't have comments."));
                    };
                    case (? cs) {
                        #ok({
                            post = post;
                            comments= ?_readComments(cs);
                            suggestions= ?_readPostSuggestions(postId);
                            likeQty= _readLikesQtyByTarget(postId);
                        });
                    };
                };
            };
        };

    };

    public query({caller}) func readPostsByArtist (artistPpal : Principal) : async Result.Result<[PostRead], Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let postsIds = artistPostsRels.get0(artistPpal);
        var postsBuff : Buffer.Buffer<PostRead> = Buffer.Buffer(0);
        label l for( pId in postsIds.vals() ){
            let targetPost = Trie.find(
                posts, 
                Utils.keyText(pId),
                Text.equal
            );

            switch(targetPost) {
                case null {
                    // #err(#Unknown("Post doesn't exist."));
                    continue l;
                };
                case (? post) {
                    
                    let targetComments = Trie.find(
                        comments, 
                        Utils.keyText(pId),
                        Text.equal
                    );

                    switch(targetComments) {
                        case null {
                            postsBuff.add({
                                post = post;
                                comments = null;
                                suggestions = ?_readPostSuggestions(pId);
                                likeQty = _readLikesQtyByTarget(pId);
                            });
                            continue l;
                        };
                        case (? cs) {
                            postsBuff.add({
                                post = post;
                                comments= ?_readComments(cs);
                                suggestions= ?_readPostSuggestions(pId);
                                likeQty= _readLikesQtyByTarget(pId);
                            });
                            continue l;
                        };
                    };
                };
            };
        };
        #ok(postsBuff.toArray());
    };
    //ExploreFeed
    public query({caller}) func readPostsByCreation (qty : Int, page : Int) : async Result.Result<[PostRead], Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let pIter : Iter.Iter<(Text, Post)> = Trie.iter(posts);
        let pBuff : Buffer.Buffer<PostRead> = Buffer.Buffer(0);
        var pCount : Int = 0;
        
        label l for (p in pIter) {

            if ( pCount < (qty*page - qty) ) {
                pCount += 1;
                continue l;
            };
            if ( pCount == qty*page ) {
                break l;
            };
            pCount += 1;

            let targetComments = Trie.find(
                comments, 
                Utils.keyText(p.0),
                Text.equal
            );

            switch(targetComments) {
                case null {
                    pBuff.add({
                        post = p.1;
                        comments = null;
                        suggestions = ?_readPostSuggestions(p.0);
                        likeQty = _readLikesQtyByTarget(p.0);
                    });
                    continue l;
                };
                case (? cs) {
                    pBuff.add({
                        post = p.1;
                        comments = ?_readComments(cs);
                        suggestions = ?_readPostSuggestions(p.0);
                        likeQty = _readLikesQtyByTarget(p.0);
                    });
                };
            };
        };

        #ok(Array.sort(pBuff.toArray(), Utils.comparePR));
    };
    //PersonalFeed
    public query({caller}) func readFollowsPostsByCreation (artistPpal : Principal, qty : Int, page : Int) : async Result.Result<[PostRead], Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let artistPpalArr : [Principal] = followsRels.get1(artistPpal);
        let pBuff : Buffer.Buffer<PostRead> = Buffer.Buffer(0);
        let pIdBuff : Buffer.Buffer<Text> = Buffer.Buffer(0);
        var pCount : Int = 0;
        
        for (a in artistPpalArr.vals()) {
            let pArr : [Text] = artistPostsRels.get0(a);

            for (p in pArr.vals()) {
                pIdBuff.add(p);
            };
        };

        label l for (pId in pIdBuff.vals()) {
            if ( pCount < (qty*page - qty) ) {
                pCount += 1;
                continue l;
            };
            if ( pCount == qty*page ) {
                break l;
            };
            pCount += 1;

        
            let targetPost = Trie.find(
                posts, 
                Utils.keyText(pId),
                Text.equal
            );

            switch(targetPost) {
                case null {
                    continue l;
                };
                case (? post) {

                    let targetComments = Trie.find(
                        comments, 
                        Utils.keyText(pId),
                        Text.equal
                    );

                    switch(targetComments) {
                        case null {
                            pBuff.add({
                                post = post;
                                comments = null;
                                suggestions = ?_readPostSuggestions(pId);
                                likeQty = _readLikesQtyByTarget(pId);
                            });
                            continue l;
                        };
                        case (? cs) {
                            pBuff.add({
                                post = post;
                                comments = ?_readComments(cs);
                                suggestions = ?_readPostSuggestions(pId);
                                likeQty = _readLikesQtyByTarget(pId);
                            });
                        };
                    };
                };
            };
        };
        #ok(Array.sort(pBuff.toArray(), Utils.comparePR));
    };
    
    public shared({caller}) func updatePost (postData : PostUpdate) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller) or Principal.notEqual(artistPostsRels.get1(postData.postId)[0], caller)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            posts,
            Utils.keyText(postData.postId),
            Text.equal
        );

        switch(result) {
            // If there are no matches, add artist
            case null {
                #err(#Unknown("Post not found"));
            };
            case (? v) {

                let newPost : Post = {
                    postBasics = postData.postBasics;
                    createdAt = v.createdAt;
                };

                posts := Trie.replace(
                    posts,
                    Utils.keyText(postData.postId),
                    Text.equal,
                    ?newPost
                ).0;
                #ok(());
            };
        };

    };

    public shared({caller}) func removePost (postId : Text) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller) or Principal.notEqual(artistPostsRels.get1(postId)[0], caller)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            posts,
            Utils.keyText(postId),
            Text.equal
        );

        switch(result) {
            case null {
                #err(#Unknown("You're trying to remove an unexisting post."));
            };
            case (? v) {
                posts := Trie.replace(
                    posts,
                    Utils.keyText(postId),
                    Text.equal,
                    null
                ).0;
                artistPostsRels.delete(caller, postId);
                _removeAllLikes(postId);
                _removeAllSuggestions(postId);
                _removeAllComments(postId);
            };
        };

    };

//Gallery
    public shared({caller}) func createGallery (galleryData : GalleryCreate) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let g = Source.Source();
        let galleryId = Text.concat("G", UUID.toText(await g.new()));

        let gallery : Gallery = {
            id = galleryId;
            artistPpal = galleryData.artistPpal;
            name = galleryData.name;
            description = galleryData.description;
            galleryBanner = galleryData.galleryBanner;
            createdAt = Time.now();
        };

        let (newArtistGalleries, existing) = Trie.put(
            galleries,
            Utils.keyText(galleryId),
            Text.equal,
            gallery
        );

        switch(existing) {
            case null {
                galleries := newArtistGalleries;
                artistGalleriesRels.put(caller, galleryId);
                #ok(());
            };
            case (? v) {
                await createGallery(galleryData);
            };
        };
    };

    public query({caller}) func readGalleriesByArtist (artistPpal : Principal) : async Result.Result<[(Text, Gallery)], Error> {
        
        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let artistGalleriesIds : [Text] = artistGalleriesRels.get0(artistPpal);
        let artistGalleries : Buffer.Buffer<(Text, Gallery)> = Buffer.Buffer(1);

        label af for (id in artistGalleriesIds.vals()) {
            let result : ?Gallery = Trie.find(
                galleries,
                Utils.keyText(id),
                Text.equal
            );

            switch (result){
                case null {
                    continue af;
                };
                case (? ag) {
                    artistGalleries.add((id, ag)); 
                };
            };
        };
        #ok(artistGalleries.toArray());
    };
    //cambio ac'a en params, se quit'o artGalleryId
    public shared({caller}) func updateArtGallery (galleryData : GalleryUpdate) : async Result.Result<(), Error> {
        
        if(Principal.isAnonymous(caller) or Principal.notEqual(artistGalleriesRels.get1(galleryData.id)[0], caller)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            galleries,
            Utils.keyText(galleryData.id),
            Text.equal 
        );

        switch(result) {
            case null {
                #err(#NonExistentItem)
            };
            case (? v) {
                if(Principal.equal(v.artistPpal, caller)) {
                    let gallery : Gallery = {
                        id = galleryData.id;
                        artistPpal = v.artistPpal;
                        name = galleryData.name;
                        description = galleryData.description;
                        galleryBanner = galleryData.galleryBanner;
                        createdAt = v.createdAt;
                    };

                    galleries := Trie.replace(
                        galleries,       
                        Utils.keyText(gallery.id), 
                        Text.equal,
                        ?gallery
                    ).0;
                    if(artistGalleriesRels.get1(galleryData.id).size() != 0) {
                        artistGalleriesRels.delete(caller, galleryData.id);
                        artistGalleriesRels.put(caller, galleryData.id);
                    };
                    return #ok(());
                };
                return #err(#NotAuthorized);
            };
        };
    };

    public shared({caller}) func removeGallery (galleryId : Text) : async Result.Result<(), Error> {
        
        if(Principal.isAnonymous(caller) or Principal.notEqual(artistGalleriesRels.get1(galleryId)[0], caller)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            galleries,
            Utils.keyText(galleryId),
            Text.equal 
        );

        switch(result) {
            case null {
                #err(#NonExistentItem)
            };
            case (? v) {
                if(Principal.equal(v.artistPpal, caller)) {
                    galleries := Trie.replace(
                        galleries,
                        Utils.keyText(galleryId),
                        Text.equal,
                        null
                    ).0;
                    if(artistGalleriesRels.get1(galleryId).size() != 0) {
                        artistGalleriesRels.delete(caller, galleryId);
                    };
                    return #ok(());
                };
                return #err(#NotAuthorized);
            };
        };
    };

//Likes
    public shared({caller}) func addLike (targetId : Text) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        likesRels.put(targetId, caller);
        #ok(());
    };

    public query({caller}) func readLikesQtyByTarget (targetId : Text) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        #ok(_readLikesQtyByTarget(targetId));

    };

    public query({caller}) func readLikesQtyByArtist (artistPpal : Principal) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        #ok(likesRels.get1(artistPpal).size());

    };

    public shared({caller}) func removeLike (targetId : Text) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        _removeLike(targetId, caller);
        #ok(());

    };
    
//Follows
    public shared({caller}) func addFollow (artistPpal : Principal) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        followsRels.put(artistPpal, caller);
        #ok(());
    };

    public query({caller}) func readArtistFollowersQty (artistPpal : Principal) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        #ok(followsRels.get0(artistPpal).size());

    };

    public query({caller}) func readArtistFollowsQty (artistPpal : Principal) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        #ok(followsRels.get1(artistPpal).size());

    };

    public shared({caller}) func removeFollow (artistPpal : Principal) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        followsRels.delete(artistPpal, caller);
        #ok(());

    };
//Suggestions
    public shared({caller}) func addSuggestion (postId : Text, suggestion : SuggestionCreate) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let g = Source.Source();
        let suggestionId = Text.concat("S", UUID.toText(await g.new()));

        let newSuggestion : Suggestion = {
            createdAt = Time.now();
            comment = suggestion.comment;
        };

        let (newSuggestions, existing) = Trie.put(
            suggestions,
            Utils.keyText(suggestionId),
            Text.equal,
            newSuggestion
        );

        switch(existing) {
            case null {
                suggestions := newSuggestions;
                postSuggestionsRels.put(postId, suggestionId);
                artistSuggestionsRels.put(caller, suggestionId);
                #ok(());
            };
            case (? v) {
                #err(#Unknown("You can only add 1 suggestion."));
            };
        };
    };

    public query({caller}) func readPostSuggestions (postId : Text) : async Result.Result<[(Principal, Text, Text, Suggestion)], Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        #ok(_readPostSuggestions(postId));

    };

    public query({caller}) func readSuggestionsQtyByPost (postId : Text) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        #ok(postSuggestionsRels.get0(postId).size());

    };

    public query({caller}) func readSuggestionsQtyByArtist (artistPpal : Principal) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        #ok(artistSuggestionsRels.get0(artistPpal).size());

    };

    public shared({caller}) func removeSuggestion (suggestionId : Text, postId : Text) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller) or Principal.notEqual(artistSuggestionsRels.get1(suggestionId)[0], caller)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            suggestions,
            Utils.keyText(suggestionId),
            Text.equal
        );

        switch(result) {
            case null {
                #err(#Unknown("You're trying to remove an unexisting suggestion."));
            };
            case (? v) {
                _removeSuggestion(suggestionId, postId, caller);
                #ok(());
            };
        };

    };
    
//Comments
    public shared({caller}) func createComment (targetId : Text, comment : CommentCreate) : async Result.Result<(), Error> {
        
        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let g = Source.Source();
        let commentId = Text.concat("C", UUID.toText(await g.new()));

        let newComment : Comment = {
            createdAt = Time.now();
            commentBasics = comment.commentBasics;
        };

        _addComment(targetId, commentId, caller, newComment);
        #ok(());
    };

    public query({caller}) func readComments (targetId : Text) : async Result.Result<[(Principal, Text, Text, Comment)], Error> {

        let targetComments = Trie.find(
            comments, 
            Utils.keyText(targetId),
            Text.equal
        );

        switch(targetComments) {
            case null {
                #err(#Unknown("Target doesn't have comments."));
            };
            case (? cs) {
                #ok(_readComments(cs));
            };
        };
    };

    public query func readCommentsQty (targetId : Text) : async Result.Result<Nat, Error>  {

        let targetComments = Trie.find(
            comments, 
            Utils.keyText(targetId),
            Text.equal
        );

        switch(targetComments) {
            case null {
                #err(#Unknown("Target doesn't have comments."));
            };
            case (? cs) {
                #ok(Trie.size(cs));
            };
        };
    };

    public shared({caller}) func removeComment (targetId : Text, commentId : Text) : async Result.Result<(), Error>  {


        if(Principal.isAnonymous(caller) or Principal.notEqual(artistCommentsRels.get1(commentId)[0], caller)) {
            return #err(#NotAuthorized);
        };

        let result = Trie.find(
            comments,
            Utils.keyText(targetId),
            Text.equal
        );

        switch(result) {
            case null {
                #err(#Unknown("You're trying to remove a comment from a Post that doesn't exist."));
            };
            case (? v) {
                _recRemoveComment(targetId, commentId);
                #ok(());
            };
        };

    };

//Username rels
    public shared({caller}) func relPrincipalWithUsername (artistP : Principal, username : Text) : async Result.Result<(), Error> {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };
        
        #ok(principalUsernameRels.put(artistP, username));
    };

//-----------End Public

//---------------Private
//Likes

    private func _readLikesQtyByTarget (targetId : Text) : Nat {
        likesRels.get0(targetId).size();
    };

    private func _removeAllLikes (targetId : Text) {

        var count = likesRels.get0(targetId).size();

        while( count > 0 ) {
            let artistPpal = likesRels.get0(targetId)[0];
            _removeLike(targetId, artistPpal);
            count -= 1;
        };

    };

    private func _removeLike (targetId : Text, artistPpal : Principal) {

        likesRels.delete(targetId, artistPpal);

    };

//Suggestions

    private func _readPostSuggestions(postId : Text) : [(Principal, Text, Text, Suggestion)] {

        let suggestionIds = postSuggestionsRels.get0(postId);

        let filteredSuggestions = Trie.filter(
            suggestions,
            func ( id : Text, sugg : Suggestion ) : Bool {
                var bool : Bool = false;
                label l for(sugs in suggestionIds.vals()) {
                    if(sugs == id) {
                        bool := true;
                        break l;
                    };
                };
                return bool;
            }
        );

        let fSsIter : Iter.Iter<(Text, Suggestion)> = Trie.iter(filteredSuggestions);
        let fSsBuff : Buffer.Buffer<(Principal, Text, Text, Suggestion)> = Buffer.Buffer(0);
        
        for (c in fSsIter) {
            let artistP = artistSuggestionsRels.get1(c.0)[0];
            let artistU = principalUsernameRels.get0(artistP)[0];

            fSsBuff.add(
                (
                    artistP,
                    artistU,
                    c.0,
                    c.1
                )
            );

        };

        fSsBuff.toArray();
    };

    private func _removeAllSuggestions (postId : Text) {

        var count = postSuggestionsRels.get0(postId).size();

        while ( count > 0) {
            let suggestionId = postSuggestionsRels.get0(postId)[count-1];
            let artistPpal = artistSuggestionsRels.get1(suggestionId)[count-1];
            _removeSuggestion(suggestionId, postId, artistPpal);
            count -= 1;
        };
    };

    private func _removeSuggestion (suggestionId : Text, postId : Text, artistPpal : Principal) {

        suggestions := Trie.replace(
            suggestions,
            Utils.keyText(suggestionId),
            Text.equal,
            null
        ).0;
        
        postSuggestionsRels.delete(postId, suggestionId);
        artistSuggestionsRels.delete(artistPpal, suggestionId);
        _removeAllLikes(suggestionId);

    };

//Comments

    private func _addComment (targetId : Text, commentId : Text, artistPpal : Principal, comment : Comment) {

        comments := Trie.put2D(
            comments,
            Utils.keyText(targetId),
            Text.equal,
            Utils.keyText(commentId),
            Text.equal,
            comment
        );

        artistCommentsRels.put(artistPpal, commentId);
    };

    private func _readComments (cs : Trie.Trie<Text, Comment>) : [(Principal, Text, Text, Comment)] {
        let fCsIter : Iter.Iter<(Text, Comment)> = Trie.iter(cs);
        let fCsBuff : Buffer.Buffer<(Principal, Text, Text, Comment)> = Buffer.Buffer(0);
        for (c in fCsIter) {
            let artistP = artistCommentsRels.get1(c.0)[0];
            let artistU = principalUsernameRels.get0(artistP)[0];

            fCsBuff.add(
                (
                    artistP,
                    artistU,
                    c.0,
                    c.1
                )
            );
        };
        fCsBuff.toArray();
    };

    //Recursively remove all comments and nested hierarchical comments.
    private func _recRemoveComment (targetId : Text, commentId : Text)  {

        let commentRoot = Trie.find(
            comments,
            Utils.keyText(commentId),
            Text.equal
        );

        switch(commentRoot) {
            case null {
                _removeCommentL2(targetId, commentId);
            };
            case (? cs) {
                let fCsIter : Iter.Iter<(Text, Comment)> = Trie.iter(cs);

                for (a in fCsIter) {
                    _recRemoveComment(commentId, a.0);
                };
                
                _removeCommentL2(targetId, commentId);
                _removeCommentL1(commentId);
            };
        };
    };

    //Remove coment content node (Layer 2)
    private func _removeCommentL2(targetId : Text, commentId : Text) {

        // let tempTrie : Trie.Trie<Text, Comment> = Trie.replace(
        //     prevTrie,
        //     Utils.keyText(commentId),
        //     Text.equal,
        //     null
        // ).0;

        comments := Trie.remove2D(
            comments,
            Utils.keyText(targetId),
            Text.equal,
            Utils.keyText(commentId),
            Text.equal
        ).0;
        _removeAllLikes(commentId);
        _removeArtistCommentsRels(commentId);

    };

    //Remove empty coment node (Layer 1)
    private func _removeCommentL1(targetId : Text) {

        comments := Trie.replace(
            comments,
            Utils.keyText(targetId),
            Text.equal,
            null
        ).0;

    };

    private func _removeAllComments(postId : Text) : Result.Result<(), Error> {

        let postComments = Trie.find(
            comments,
            Utils.keyText(postId),
            Text.equal
        );

        switch(postComments) {
            case null {
                #ok(());
            };
            case (? cs) {
                let fCsIter : Iter.Iter<(Text, Comment)> = Trie.iter(cs);

                for (a in fCsIter) {
                    _recRemoveComment(postId, a.0);
                };
                _removeCommentL1(postId);
                #ok(());
            };
        };
    };
    
//ArtistCommentsRel

    private func _removeArtistCommentsRels (targetId : Text) {

        var count = artistCommentsRels.get1(targetId).size();
        
        while( count > 0 ) {
            let artistPpal = artistCommentsRels.get1(targetId)[0];
            _removeArtistCommentRels(artistPpal, targetId);
            count -= 1;
        };
    };

    private func _removeArtistCommentRels (artistPpal : Principal, targetId : Text) {

        artistCommentsRels.delete(artistPpal , targetId);

    };

    //Estos v1 son validando nuevamente la existencia de los Trie pero es redundante.
    //Remove coment content node (Layer 2) v1
    // private func _removeCommentL2v1(targetId : Text, commentId : Text) {

    //     let filteredComments = Trie.find(
    //         comments,
    //         Utils.keyText(targetId),
    //         Text.equal
    //     );

    //     switch(filteredComments) {
    //         case null {
    //             #err(#NotFound);
    //         };
    //         case (? fCs) {
    //             let comment = Trie.find(
    //                 fCs,
    //                 Utils.keyText(commentId),
    //                 Text.equal
    //             );

    //             switch(comment) {
    //                 case null {
    //                     #err(#NotFound);
    //                 };
    //                 case (? c) {
    //                     fCs := Trie.replace(
    //                         fCs,
    //                         Utils.keyText(commentId),
    //                         Text.equal,
    //                         null
    //                     ).0;

    //                     comments := Trie.replace(
    //                         comments,
    //                         Utils.keyText(targetId),
    //                         Text.equal,
    //                         fCs
    //                     ).0;
    //                     _removeAllLikes(commentId);
    //                     _removeAllSuggestions(commentId);
    //                     _removeArtistCommentsRels
    //                     #ok(());
    //                 };
    //             };
    //         };
    //     };

    // };
    //Remove empty coment node (Layer 1) v1
    // private func _removeCommentL1v1(targetId : Text) {

    //     let comment = Trie.find(
    //         comments,
    //         Utils.keyText(targetId),
    //         Text.equal
    //     );

    //     switch(comment) {
    //         case null {
    //             #err(#NotFound);
    //         };
    //         case (? fCs) {
    //             comments := Trie.replace(
    //                 comments,
    //                 Utils.keyText(targetId),
    //                 Text.equal,
    //                 null
    //             ).0;

    //         };
    //     };

    // };

//-----------End Private

//---------------Admin
    public query({caller}) func authorizedArr() : async Result.Result<[Principal], Error> {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        return #ok(authorized);
    };

    public query({caller}) func authorize(principal : Principal) : async Result.Result<(), Error> {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        authorized := Array.append(authorized, [principal]);
        #ok(());
    };
//---------------End Admin


//---------------For internal test only

    public query({caller}) func readFirstPostId (artistPpal : Principal) : async Text {

        artistPostsRels.get0(artistPpal)[0];
    };

    public query func commentsSize() :async Nat {
        Trie.size(comments);
    };

    public query({caller}) func artistsCommentsSize(principal : Principal) :async Nat {
        artistCommentsRels.get0(principal).size();
    };

    public query({caller}) func readFirstCommentById (targetId : Text) : async Text {

        let targetComments = Trie.find(
            comments, 
            Utils.keyText(targetId),
            Text.equal
        );

        switch(targetComments) {
            case null {
                "Target doesn't have comments.";
            };
            case (? cs) {
                let fCsIter : Iter.Iter<(Text, Comment)> = Trie.iter(cs);
                Iter.toArray(fCsIter)[0].0;
            };
        };
    };
//-----------End For internal tests only.

};