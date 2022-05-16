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
import Blob "mo:base/Blob";
import Rels "./Rels/Rels";
import Source "mo:uuid/async/SourceV4";
import UUID "mo:uuid/UUID";
import Utils "./utils";
import Debug "mo:base/Debug";

import assetC "./actorClasses/asset/assetCanister";

shared({ caller = owner }) actor class(initOptions: Types.InitOptions) = this {

//Types
    type Error = Types.Error;
    type PostCreate = Types.PostCreate;
    type PostUpdate = Types.PostUpdate;
    type Post = Types.Post;
    type PostRead = Types.PostRead;
    type ArtistRead = Types.ArtistRead;
    type Follow = Types.Follow;
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
    //Reemplazar por el assetCanister correspondiente
    stable var assetCanisterIds : [Principal] = [];

    stable var authorized : [Principal] = initOptions.authorized;

    stable var posts : Trie.Trie<Text, Post> = Trie.empty();//postId,Post
    
    stable var galleries : Trie.Trie<Text, Gallery> = Trie.empty();//postId,Gallery

    stable var suggestions : Trie.Trie<Text, Suggestion> = Trie.empty();//suggestionId,Suggestion

    stable var comments : Trie.Trie2D<Text, Text, Comment> = Trie.empty(); //postId|commentId|suggestionId,(commentId|suggestionCommentId,comment)

    stable var likes : [(Text, Principal)] = [];//postId|commentId|suggestionCommentId,artistPrincipal
    let likesRels = Rels.Rels<Text, Principal>((Text.hash, Principal.hash), (Text.equal, Principal.equal), likes);

    stable var follows : [(Principal, Principal)] = [];//artistPrincipal,followerPrincipal
    let followsRels = Rels.Rels<Principal, Principal>((Principal.hash, Principal.hash), (Principal.equal, Principal.equal), follows);
    
    stable var principalUsername : [(Principal, Text)] = [];//artistPrincipal,artistUsername
    let principalUsernameRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), principalUsername);

    stable var postSuggestionsRelEntries : [(Text,Text)] = [];//postId,suggestionCommentId
    let postSuggestionsRels = Rels.Rels<Text, Text>((Text.hash, Text.hash), (Text.equal, Text.equal), postSuggestionsRelEntries);
    
    stable var artistSuggestions : [(Principal,Text)] = [];//artistPrincipal,suggestionId
    let artistSuggestionsRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), artistSuggestions);

    stable var artistPostsRelEntries : [(Principal, Text)] = []; //artistPrincipal,postId
    let artistPostsRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), artistPostsRelEntries); //artistPrincipal,postId

    stable var artistComments : [(Principal, Text)] = [];//artistPrincipal,commentId
    let artistCommentsRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), artistComments);

    stable var galleryPostRelEntries : [(Text,Text)] = [];
    let galleryPostRels = Rels.Rels<Text, Text>((Text.hash, Text.hash), (Text.equal, Text.equal), galleryPostRelEntries);
    
    stable var artistGalleriesRelEntries : [(Principal,Text)] = [];
    let artistGalleriesRels = Rels.Rels<Principal, Text>((Principal.hash, Text.hash), (Principal.equal, Text.equal), artistGalleriesRelEntries);
    
//---------------Public
//Artist

    public query({caller}) func readArtistProfile (username : Text) : async Result.Result<ArtistRead, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let artistPpal : Principal = principalIds[0];

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
                                artistUsername = principalUsernameRels.get0(artistPostsRels.get1(pId)[0])[0];
                                postId = pId;
                                post = post;
                                comments = null;
                                suggestions = ?_readPostSuggestions(pId);
                                likesQty = _readLikesQtyByTarget(pId);
                                likedByCaller = _isPostLikedByUser(pId, caller);
                            });
                            continue l;
                        };
                        case (? cs) {
                            postsBuff.add({
                                artistUsername = principalUsernameRels.get0(artistPostsRels.get1(pId)[0])[0];
                                postId = pId;
                                post = post;
                                comments= ?_readComments(cs);
                                suggestions= ?_readPostSuggestions(pId);
                                likesQty= _readLikesQtyByTarget(pId);
                                likedByCaller = _isPostLikedByUser(pId, caller);
                            });
                            continue l;
                        };
                    };
                };
            };
        };
        if (postsBuff.toArray().size() == 0) {
            return #ok({
                postsRead = null;
                followersQty = _readFollowersQty(artistPpal);
                followsQty = _readFollowsQty(artistPpal);
                postsQty = _readPostsQty(artistPpal);
                galleriesQty = _readGalleriesQty(artistPpal);
                followedByCaller =  _followedBy(artistPpal, caller);
            });
        };
        #ok({
            postsRead = ?postsBuff.toArray(); 
            followersQty = _readFollowersQty(artistPpal);
            followsQty = _readFollowsQty(artistPpal);
            postsQty = _readPostsQty(artistPpal);
            galleriesQty = _readGalleriesQty(artistPpal);
            followedByCaller =  _followedBy(artistPpal, caller);
        });
    };

    public shared({caller}) func removeArtist () : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };
        if(principalUsernameRels.get0(caller).size() == 0) {
            return #err(#NonExistentItem);
        };

        let postIds : [Text] = artistPostsRels.get0(caller);

        label l for (postId in postIds.vals()) {

            let result = Trie.find(
                posts,
                Utils.keyText(postId),
                Text.equal
            );

            switch(result) {
                case null {
                    continue l;
                };
                case (? v) {
                    posts := Trie.replace(
                        posts,
                        Utils.keyText(postId),
                        Text.equal,
                        null
                    ).0;
                    // await _deleteImage(postId);
                    artistPostsRels.delete(caller, postId);
                    _removeAllLikes(postId);
                    _removeAllSuggestions(postId);
                    let waste = _removeAllComments(postId);
                    for(gI in galleryPostRels.get1(postId).vals()){
                        galleryPostRels.delete(gI, postId);
                    };
                    continue l;
                };
            };
        };
        _removeAllFollows(caller);
        _removeArtistGalleries(caller);
        principalUsernameRels.delete(caller, principalUsernameRels.get0(caller)[0]);
        #ok(());
    };

//Post
    public shared({caller}) func createPost (postData : PostCreate) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let g = Source.Source();
        let postId = Text.concat("P", UUID.toText(await g.new()));
        // var assetName = "http://localhost:8000/";
        // assetName := Text.concat(assetName,  postId);
        // assetName := Text.concat(assetName, "?canisterId=");
        // assetName := Text.concat(assetName, Principal.toText(assetCanisterIds[0]));
        
        let assetName = "http://" # Principal.toText(assetCanisterIds[0]) # ".raw.ic0.app/A" # postId;

        let fullPostBasics = {
            // asset = Text.concat(Principal.toText(assetCanisterIds[0]), Text.concat(".raw.ic0.app/", postId));
            asset = assetName;
            title = postData.postBasics.title;
            description = postData.postBasics.description;
            artType = postData.postBasics.artType;
            tags = postData.postBasics.tags;
            artCategory = postData.postBasics.artCategory;
            tools = postData.postBasics.tools;
            details = postData.postBasics.details;
        };
        let post : Post = {
            createdAt = Time.now();
            postBasics = fullPostBasics;
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
                
                await _storeImage(postId, postData.postImage);

                artistPostsRels.put(caller, postId);
                label l for(d in postData.postBasics.details.vals()) {
                    if(d.0 == "galleryId") {
                        switch(d.1){
                            case(#Text(g)) {
                                galleryPostRels.put(g, postId);
                                break l;
                            };
                            case(#Vec(galls)) {
                                for(g in galls.vals()) {
                                    switch(g){
                                        case(#Text(gId)) {
                                            galleryPostRels.put(gId, postId);
                                            break l;
                                        };
                                        case(_) {
                                            break l;
                                        };
                                    };
                                };
                                break l;
                            };
                            case (_) {
                                break l;
                            };
                        };
                    }
                };
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
                        #ok({
                            artistUsername = principalUsernameRels.get0(artistPostsRels.get1(postId)[0])[0];
                            postId = postId;
                            post = post;                                
                            comments = null;
                            suggestions = ?_readPostSuggestions(postId);
                            likesQty = _readLikesQtyByTarget(postId);
                            likedByCaller = _isPostLikedByUser(postId, caller);
                        });
                    };
                    case (? cs) {
                        #ok({
                            artistUsername = principalUsernameRels.get0(artistPostsRels.get1(postId)[0])[0];
                            postId = postId;
                            post = post;                                
                            comments = ?_readComments(cs);
                            suggestions = ?_readPostSuggestions(postId);
                            likesQty = _readLikesQtyByTarget(postId);
                            likedByCaller = _isPostLikedByUser(postId, caller);
                        });
                    };
                };
            };
        };

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

            let artistPrincipal : Principal = artistPostsRels.get1(p.0)[0];

            if(Principal.equal(caller, artistPrincipal)) { continue l; };
            
            switch(targetComments) {
                case null {
                    pBuff.add({
                        artistUsername = principalUsernameRels.get0(artistPrincipal)[0];
                        postId = p.0;
                        post = p.1;
                        comments = null;
                        suggestions = ?_readPostSuggestions(p.0);
                        likesQty = _readLikesQtyByTarget(p.0);
                        likedByCaller = _isPostLikedByUser(p.0, caller);
                    });
                    continue l;
                };
                case (? cs) {
                    pBuff.add({
                        artistUsername = principalUsernameRels.get0(artistPostsRels.get1(p.0)[0])[0];
                        postId = p.0;
                        post = p.1;
                        comments = ?_readComments(cs);
                        suggestions = ?_readPostSuggestions(p.0);
                        likesQty = _readLikesQtyByTarget(p.0);
                        likedByCaller = _isPostLikedByUser(p.0, caller);
                    });
                };
            };
        };
        #ok(Array.sort(pBuff.toArray(), Utils.comparePR));
    };

    //PersonalFeed
    public query({caller}) func readFollowsPostsByCreation (username : Text, qty : Int, page : Int) : async Result.Result<[PostRead], Error> {
    
        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);

        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        if(Principal.notEqual(caller, principalIds[0])) {
            return #err(#NotAuthorized);
        };

        let artistPpal : Principal = principalIds[0];

        let artistPpalArr : [Principal] = followsRels.get1(artistPpal);
        let pBuff : Buffer.Buffer<PostRead> = Buffer.Buffer(0);
        let pIdBuff : Buffer.Buffer<Text> = Buffer.Buffer(0);
        var pCount : Int = 0;
        
        label l for (a in artistPpalArr.vals()) {
            if(Principal.equal(caller, a)) { continue l; };
            let pArr : [Text] = artistPostsRels.get0(a);

            for (p in pArr.vals()) {
                pIdBuff.add(p);
            };
        };

        label m for (pId in pIdBuff.vals()) {
            if ( pCount < (qty*page - qty) ) {
                pCount += 1;
                continue m;
            };
            if ( pCount == qty*page ) {
                break m;
            };
            pCount += 1;

        
            let targetPost = Trie.find(
                posts, 
                Utils.keyText(pId),
                Text.equal
            );

            switch(targetPost) {
                case null {
                    continue m;
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
                                artistUsername = principalUsernameRels.get0(artistPostsRels.get1(pId)[0])[0];
                                postId = pId;
                                post = post;
                                comments = null;
                                suggestions = ?_readPostSuggestions(pId);
                                likesQty = _readLikesQtyByTarget(pId);
                                likedByCaller = _isPostLikedByUser(pId, caller);
                            });
                            continue m;
                        };
                        case (? cs) {
                            pBuff.add({
                                artistUsername = principalUsernameRels.get0(artistPostsRels.get1(pId)[0])[0];
                                postId = pId;
                                post = post;
                                comments = ?_readComments(cs);
                                suggestions = ?_readPostSuggestions(pId);
                                likesQty = _readLikesQtyByTarget(pId);
                                likedByCaller = _isPostLikedByUser(pId, caller);
                            });
                        };
                    };
                };
            };
        };
        #ok(Array.sort(pBuff.toArray(), Utils.comparePR));
    };

    public query({caller}) func readPostsByGallery (galleryId : Text, qty : Int, page : Int) : async Result.Result<[PostRead], Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let postsIds : [Text] = galleryPostRels.get0(galleryId);
        let pBuff : Buffer.Buffer<PostRead> = Buffer.Buffer(0);
        var pCount : Int = 0;

        label l for (postId in postsIds.vals()) {
            
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
                Utils.keyText(postId),
                Text.equal
            );

            switch(targetPost) {
                case null {
                    continue l;
                };
                case (? post) {

                    let targetComments = Trie.find(
                        comments,
                        Utils.keyText(postId),
                        Text.equal
                    );

                    switch(targetComments) {
                        case null {
                            pBuff.add({
                                artistUsername = principalUsernameRels.get0(artistPostsRels.get1(postId)[0])[0];
                                postId = postId;
                                post = post;
                                comments = null;
                                suggestions = ?_readPostSuggestions(postId);
                                likesQty = _readLikesQtyByTarget(postId);
                                likedByCaller = _isPostLikedByUser(postId, caller);
                            });
                            continue l;
                        };
                        case (? cs) {
                            pBuff.add({
                                artistUsername = principalUsernameRels.get0(artistPostsRels.get1(postId)[0])[0];
                                postId = postId;
                                post = post;
                                comments = ?_readComments(cs);
                                suggestions = ?_readPostSuggestions(postId);
                                likesQty = _readLikesQtyByTarget(postId);
                                likedByCaller = _isPostLikedByUser(postId, caller);
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

                for(gI in galleryPostRels.get1(postData.postId).vals()){
                    galleryPostRels.delete(gI, postData.postId);
                };

                label l for(d in postData.postBasics.details.vals()) {
                    if(d.0 == "galleryId") {
                        switch(d.1){
                            case(#Text(g)) {
                                galleryPostRels.put(g, postData.postId);
                                break l;
                            };
                            case(#Vec(galls)) {
                                label m for(g in galls.vals()) {
                                    switch(g){
                                        case(#Text(gId)) {
                                            galleryPostRels.put(gId, postData.postId);
                                            break m;
                                        };
                                        case(_) {
                                            break m;
                                        };
                                    };
                                };
                                break l;
                            };
                            case (_) {
                                break l;
                            };
                        };
                    }
                };
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
                await _deleteImage(postId);
                artistPostsRels.delete(caller, postId);
                _removeAllLikes(postId);
                _removeAllSuggestions(postId);
                for(gI in galleryPostRels.get1(postId).vals()){
                    galleryPostRels.delete(gI, postId);
                };
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

    public query({caller}) func readGalleriesByArtist (username : Text) : async Result.Result<[Gallery], Error> {
        
        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let artistPpal : Principal = principalIds[0];

        let artistGalleriesIds : [Text] = artistGalleriesRels.get0(artistPpal);
        let artistGalleries : Buffer.Buffer<Gallery> = Buffer.Buffer(1);

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
                    artistGalleries.add(ag); 
                };
            };
        };
        #ok(artistGalleries.toArray());
    };
    
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
                        for(postId in galleryPostRels.get0(galleryId).vals()){
                            galleryPostRels.delete(galleryId, postId);
                        };
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

    public query({caller}) func readLikesQtyByArtist (username : Text) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let artistPpal : Principal = principalIds[0];


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
    public shared({caller}) func addFollow (username : Text) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let artistPpal : Principal = principalIds[0];

        followsRels.put(artistPpal, caller);
        #ok(());
    };

    public query({caller}) func readArtistFollowersQty (username : Text) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let artistPpal : Principal = principalIds[0];

        #ok(followsRels.get0(artistPpal).size());

    };

    public query({caller}) func readArtistFollowers (username : Text) : async Result.Result<[Follow], Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let followersIds : [Principal] = followsRels.get0(principalIds[0]);

        let followers : Buffer.Buffer<Follow> = Buffer.Buffer(followersIds.size());

        for(artistPpal in followersIds.vals()) {
            followers.add({
                followedByCaller = _followedBy(artistPpal, caller);
                artistUsername = principalUsernameRels.get0(artistPpal)[0];
                artistPrincipal = artistPpal;
            });
        };
        #ok(followers.toArray());
    };

    public query({caller}) func readArtistFollows (username : Text) : async Result.Result<[Follow], Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let followsIds : [Principal] = followsRels.get1(principalIds[0]);
        let follows : Buffer.Buffer<Follow> = Buffer.Buffer(followsIds.size());

        for(artistPpal in followsIds.vals()) {
            follows.add({
                followedByCaller = _followedBy(artistPpal, caller);
                artistUsername = principalUsernameRels.get0(artistPpal)[0];
                artistPrincipal = artistPpal;
            });
        };
        #ok(follows.toArray());

    };

    public query({caller}) func readArtistFollowsQty (username : Text) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let artistPpal : Principal = principalIds[0];

        #ok(followsRels.get1(artistPpal).size());

    };

    public shared({caller}) func removeFollow (username : Text) : async Result.Result<(), Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let artistPpal : Principal = principalIds[0];

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

    public query({caller}) func readSuggestionsQtyByArtist (username : Text) : async Result.Result<Nat, Error> {

        if(Principal.isAnonymous(caller)) {
            return #err(#NotAuthorized);
        };

        let principalIds : [Principal] = _getPrincipalByUsername(username);
    
        if(principalIds.size() == 0) {
            return #err(#NonExistentItem);
        };

        let artistPpal : Principal = principalIds[0];

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

//Username
    public shared({caller}) func relPrincipalWithUsername (artistP : Principal, username : Text) : async Result.Result<(), Error> {

        if( Principal.isAnonymous(caller) or Principal.notEqual(artistP, caller)) {
            return #err(#NotAuthorized);
        };

        if(principalUsernameRels.get0(artistP).size() != 0){
            for(u in principalUsernameRels.get0(artistP).vals()) {
                principalUsernameRels.delete(artistP, u);
            }
        };
            principalUsernameRels.put(artistP, username);
        #ok();
    };

//-----------End Public

//---------------Private
//Posts

    private func _storeImage(key : Text, asset : Blob) : async () {
        
        let aCActor = actor(Principal.toText(assetCanisterIds[0])): actor { 
            store : shared ({
                key : Text;
                content_type : Text;
                content_encoding : Text;
                content : [Nat8];
                sha256 : ?[Nat8];
            }) -> async ()
        };
        let result = await aCActor.store({
                key = key;
                content_type = "image/jpeg";
                content_encoding = "identity";
                content = Blob.toArray(asset);
                sha256 = null;
        });
    };

    private func _deleteImage(key : Text) : async () {
        
        let aCActor = actor(Principal.toText(assetCanisterIds[0])): actor { 
            delete_asset : shared ({
                key : Text;
            }) -> async ()
        };
        await aCActor.delete_asset({
                key = key;
        });

    };

    private func _readPostsQty(artistPpal : Principal) : Nat {
        artistPostsRels.get0(artistPpal).size();
    };

//Follows

    private func _readFollowersQty(artistPpal : Principal) : Nat {
        followsRels.get0(artistPpal).size();
    };

    private func _readFollowsQty(artistPpal : Principal) : Nat {
        followsRels.get1(artistPpal).size();
    };

    private func _followedBy (artistPrincipal : Principal, userPrincipal : Principal) : Bool {
        followsRels.isMember(artistPrincipal, userPrincipal);
    };

    private func _removeAllFollows (userPrincipal : Principal) {
        let followings = followsRels.get1(userPrincipal);
        let followers = followsRels.get0(userPrincipal);
        for(fings in followings.vals()) {
            _removeFollows(fings, userPrincipal);
        };

        for(fers in followers.vals()) {
            _removeFollows(userPrincipal, fers);
        };
    };

    private func _removeFollows (artistPrincipal : Principal, userPrincipal : Principal) {
        followsRels.delete(artistPrincipal, userPrincipal);
    };

//Galleries

    private func _readGalleriesQty(artistPpal : Principal) : Nat {
        artistGalleriesRels.get0(artistPpal).size();
    };

    private func _removeArtistGalleries(artistPrincipal : Principal) {

        let artistGalleriesIds = artistGalleriesRels.get0(artistPrincipal);

        for (aGId in artistGalleriesIds.vals()) {
            let dummy = _removeGallery(aGId, artistPrincipal);
        };

    };

    private func _removeGallery(galleryId: Text, artistPpal : Principal) : Result.Result<(), Error> {

        let result = Trie.find(
            galleries,
            Utils.keyText(galleryId),
            Text.equal 
        );

        switch(result) {
            case null {
                #err(#NonExistentItem);
            };
            case (? v) {
                if(Principal.equal(v.artistPpal, artistPpal)) {
                    galleries := Trie.replace(
                        galleries,
                        Utils.keyText(galleryId),
                        Text.equal,
                        null
                    ).0;
                    if(artistGalleriesRels.get1(galleryId).size() != 0) {
                        artistGalleriesRels.delete(artistPpal, galleryId);
                        for(postId in galleryPostRels.get0(galleryId).vals()){
                            galleryPostRels.delete(galleryId, postId);
                        };
                    };
                };
                #ok(());
            };
        };
    };

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

    private func _isPostLikedByUser (postId : Text, userPrincipal : Principal) : Bool {
        likesRels.isMember(postId, userPrincipal);
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

    // private func _countComment ( targetId : Text ) : Result.Result<Nat, Error> {

    // };
    
//Artist

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

    private func _getPrincipalByUsername (username : Text) : [Principal] {
        principalUsernameRels.get1(username);
    };
//-----------End Private

//---------------Upgrades
    private func getAllLikesRels () : [(Text, Principal)] {
        likesRels.getAll();
    };
    private func getAllFollowsRels () : [(Principal, Principal)] {
        followsRels.getAll();
    };
    private func getAllPrincipalUsernameRels () : [(Principal, Text)] {
        principalUsernameRels.getAll();
    };
    private func getAllPostSuggestionsRels () : [(Text, Text)] {
        postSuggestionsRels.getAll();
    };
    private func getAllArtistSuggestionsRels () : [(Principal, Text)] {
        artistSuggestionsRels.getAll();
    };
    private func getAllArtistPostsRels () : [(Principal, Text)] {
        artistPostsRels.getAll();
    };
    private func getAllArtistCommentsRels () : [(Principal, Text)] {
        artistCommentsRels.getAll();
    };
    private func getAllGalleryPostRels () : [(Text, Text)] {
        galleryPostRels.getAll();
    };
    private func getAllArtistGalleriesRels () : [(Principal, Text)] {
        artistGalleriesRels.getAll();
    };


    system func preupgrade() {

        likes := getAllLikesRels();
        follows := getAllFollowsRels();
        principalUsername := getAllPrincipalUsernameRels();
        postSuggestionsRelEntries := getAllPostSuggestionsRels();
        artistSuggestions := getAllArtistSuggestionsRels();
        artistPostsRelEntries := getAllArtistPostsRels();
        artistComments := getAllArtistCommentsRels();
        galleryPostRelEntries := getAllGalleryPostRels();
        artistGalleriesRelEntries := getAllArtistGalleriesRels();

    };

    system func postupgrade() {
        
        likes := [];
        follows := [];
        principalUsername := [];
        postSuggestionsRelEntries := [];
        artistSuggestions := [];
        artistPostsRelEntries := [];
        artistComments := [];
        galleryPostRelEntries := [];
        artistGalleriesRelEntries := [];

    };

//-----------End upgrades

//---------------Admin

    public shared({caller}) func createAssetCan () : async Result.Result<(Principal, Principal), Error> {

        if(not Utils.isAuthorized(caller, authorized)) {
            return #err(#NotAuthorized);
        };

        if(assetCanisterIds.size() != 0) { return #err(#Unknown("Already exists")); };

        let tb : Buffer.Buffer<Principal> = Buffer.Buffer(1);
        let assetCan = await assetC.Assets(caller);
        let assetCanisterId = await assetCan.getCanisterId();

        tb.add(assetCanisterId);

        assetCanisterIds := tb.toArray();

        return #ok((Principal.fromActor(this), assetCanisterId));

    };

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