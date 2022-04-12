
module {

    public type Post = {
        postBasics: PostBasics;
        createdAt: Int;
    };
    public type PostCreate = {
        postBasics: PostBasics;
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
        comments: ?[(Text, Comment)];
        suggestions: ?[(Text, Suggestion)];
        likeQty: Nat;
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