#! /bin/sh

principal=$(dfx identity get-principal)

echo "My principal: " $principal

# Create 1 post
echo "Creating post..."
dfx canister call socials createPost '(record {postBasics=record {title="Ávila Chuao"; tools=opt vec {record {"Camera"; "SONY ilce-3000k"}; record {"Lens"; "18-55mm"}}; thumbnail="https://www.google.com/url?sa=i&url=https%3A%2F%2Fmiguelev.com%2Funadjustednonraw_thumb_473%2F&psig=AOvVaw1ROuS4UNDW-MVnEx1XORrl&ust=1649854587680000&source=images&cd=vfe&ved=0CAoQjRxqFwoTCLC6n8PJjvcCFQAAAAAdAAAAABAD"; tags=vec {"avila"; "caracas"; "chuao"}; artType="Photography"; description="Ávila Chuao"; artCategory="Landscape"; details=vec {}}})'

# Get Posts by Principal
echo "Get my posts by principal"
dfx canister call socials readPostsByArtist '(principal "'$principal'")'

echo "Get postId"
postId=$(dfx canister call socials readFirstPostId '(principal "'$principal'")')
echo $postId

# Update post
echo "Updating post..."
dfx canister call socials updatePost '(record {postId='$postId'; postBasics=record {title="Ávila Caurimare"; tools=opt vec {record {"Camera"; "SONY ilce-3000k"}; record {"Lens"; "18-55mm"}}; thumbnail="https://www.google.com/url?sa=i&url=https%3A%2F%2Fmiguelev.com%2Funadjustednonraw_thumb_473%2F&psig=AOvVaw1ROuS4UNDW-MVnEx1XORrl&ust=1649854587680000&source=images&cd=vfe&ved=0CAoQjRxqFwoTCLC6n8PJjvcCFQAAAAAdAAAAABAD"; tags=vec {"avila"; "caracas"; "caurimare"}; artType="Photography"; description="Ávila Caurimare"; artCategory="Landscape"; details=vec {}}})'

# Get Post by PostId
echo "Read post by Id, must return updated post with Ávila Caurimare as name"
dfx canister call socials readPostById '('$postId')'

# Remove
echo "Remove post, must return variant ok"
dfx canister call socials removePost '('$postId')'

# Get Post by PostId
echo "Read post by Id, must return err: Post doesn't exist."
dfx canister call socials readPostById '('$postId')'

# Get Posts by Principal
echo "Read post by Principal, must return empty vec"
dfx canister call socials readPostsByArtist '(principal "'$principal'")'