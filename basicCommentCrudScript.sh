#! /bin/sh

principal=$(dfx identity get-principal)

echo "My principal: " $principal

# Create 1 post
echo "Creating post..."
dfx canister call socials createPost '(record {postBasics=record {title="Ávila Chuao"; tools=opt vec {record {"Camera"; "SONY ilce-3000k"}; record {"Lens"; "18-55mm"}}; thumbnail="https://www.google.com/url?sa=i&url=https%3A%2F%2Fmiguelev.com%2Funadjustednonraw_thumb_473%2F&psig=AOvVaw1ROuS4UNDW-MVnEx1XORrl&ust=1649854587680000&source=images&cd=vfe&ved=0CAoQjRxqFwoTCLC6n8PJjvcCFQAAAAAdAAAAABAD"; tags=vec {"avila"; "caracas"; "chuao"}; artType="Photography"; description="Ávila Chuao"; artCategory="Landscape"; details=vec {}}})'

echo "Get PostId"
postId=$(dfx canister call socials readFirstPostId '(principal "'$principal'")')
echo $postId

# Create 1 comment
echo "Creating comment..."
dfx canister call socials createComment '('$postId', record {commentBasics=record {content="Este es el comentario número 1"; details=null; category=null}})'

#Get CommentId
echo "Get commentId"
commentId=$(dfx canister call socials readFirstCommentById '('$postId')')
echo $commentId

# Get Post by PostId
echo "Read post by Id, must return post with comments."
dfx canister call socials readPostById '('$postId')'

# Create 1 comment inside a comment
echo "Creating comment in a comment..."
dfx canister call socials createComment '('$commentId', record {commentBasics=record {content="Este es el comentario 1 dentro del comentario 1"; details=null; category=null}})'

# Create another comment inside a comment
echo "Creating another comment in a comment..."
dfx canister call socials createComment '('$commentId', record {commentBasics=record {content="Este es el comentario 2 dentro del comentario 1"; details=null; category=null}})'

# Create another comment inside a comment
echo "Creating another comment in a comment..."
dfx canister call socials createComment '('$commentId', record {commentBasics=record {content="Este es el comentario 3 dentro del comentario 1"; details=null; category=null}})'

# Get Comments by CommentId
echo "Read comment by parent commentId, must return comments."
dfx canister call socials readComments '('$commentId')'

# Remove Comments by CommentId
# echo "Remove comment."
# dfx canister call socials removeComments '('$commentId')'

# Get Comments by CommentId
# echo "Read comment by parent commentId, must return none."
# dfx canister call socials readComments '('$commentId')'

# Get Posts by Principal
# echo "Consulta mis posts por mi principal"
# dfx canister call socials readPostsByArtist '(principal "'$principal'")'

# # Update post
# echo "Updating post..."
# dfx canister call socials updatePost '(record {postId='$postId'; postBasics=record {title="Ávila Caurimare"; tools=opt vec {record {"Camera"; "SONY ilce-3000k"}; record {"Lens"; "18-55mm"}}; thumbnail="https://www.google.com/url?sa=i&url=https%3A%2F%2Fmiguelev.com%2Funadjustednonraw_thumb_473%2F&psig=AOvVaw1ROuS4UNDW-MVnEx1XORrl&ust=1649854587680000&source=images&cd=vfe&ved=0CAoQjRxqFwoTCLC6n8PJjvcCFQAAAAAdAAAAABAD"; tags=vec {"avila"; "caracas"; "caurimare"}; artType="Photography"; description="Ávila Caurimare"; artCategory="Landscape"; details=vec {}}})'

# # Get Post by PostId
# echo "Read post by Id, must return updated post with Ávila Caurimare as name"
# dfx canister call socials readPostById '('$postId')'

# # Remove
# echo "Remove post, must return variant ok"
# dfx canister call socials removePost '('$postId')'

# # Get Post by PostId
# echo "Read post by Id, must return err: Post doesn't exist."
# dfx canister call socials readPostById '('$postId')'

# # Get Posts by Principal
# echo "Read post by Principal, must return empty vec"
# dfx canister call socials readPostsByArtist '(principal "'$principal'")'