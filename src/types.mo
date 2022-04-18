
module {

    public type Post = {
        postBasics: PostBasics;
        createdAt: Int;
    };
    public type PostCreate = {
        postBasics: PostBasics;
        postImage: Blob;
    };
    public type PostUpdate = {
        postId: Text;
        postBasics: PostBasics;
    };
    public type PostBasics = {
        thumbnail : Text;
        title: Text;
        description: Text;
        artType: Text;
        tags: [Text];
        artCategory: Text;
        tools: ?[(Text, Text)];
        details: [(Text, DetailValue)];
    };
    public type PostRead = {
        post: Post;
        comments: ?[(Principal, Text, Text, Comment)];
        suggestions: ?[(Principal, Text, Text, Suggestion)];
        likesQty: Int;
    };

    public type ArtistRead = {
        postsRead: [PostRead];
        followersQty: Nat;
        followsQty: Nat;
        postsQty: Nat;
        galleriesQty: Nat;
    };

    public type Gallery = {
        id: Text;
        artistPpal: Principal;
        name: Text;
        description: Text;
        galleryBanner: ?Text; 
        createdAt: Int;
    };

    public type GalleryCreate = {
        artistPpal: Principal;
        name: Text;
        description: Text;
        galleryBanner: ?Text; 
    };

    public type GalleryUpdate = {
        id: Text;
        name: Text;
        description: Text;
        galleryBanner: ?Text; 
    };

    public type CommentBasics = {
        content: Text;
        category: ?Text;
        details: ?[(Text, DetailValue)];
    };

    public type Comment = {
        commentBasics: CommentBasics;
        createdAt: Int;
    };

    public type AllComments = {
        comment: Comment;
        comments: AllComments;
    };

    public type CommentCreate = {
        commentBasics: CommentBasics;
    };
    public type CommentUpdate = {
        commentId: Text;
        commentBasics: CommentBasics;
    };
    public type Suggestion = {
        //Add suggestion category.
        comment: CommentCreate;
        createdAt: Int;
    };
    public type SuggestionCreate = {
        comment: CommentCreate;
    };
    public type SuggestionUpdate = {
        suggestionId: Text;
        postBasics: PostBasics;
    };
    public type DetailValue = {
        #I64 : Int64;
        #U64 : Nat64;
        #Vec : [DetailValue];
        #Slice : [Nat8];
        #Text : Text;
        #True;
        #False;
        #Float : Float;
        #Principal : Principal;
    };

    public type Error = {
        #NotAuthorized;
        #NonExistentItem;
        #BadParameters;
        #Unknown : Text;
    };
    
};