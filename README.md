# socials

Social network for artists.

## Deploy it

### 1. Deploy socials canister
```bash
dfx deploy socials --argument '(record { authorized = vec { principal "'$(dfx identity get-principal)'" }})'
```

### 1. Deploy its asset canister
```bash
dfx canister call socials createAssetCan
```

## Test it

### 1. Assign Username to your principal.

```bash
export USERNAME="capuzr"    
dfx canister call socials relPrincipalWithUsername '(principal "'$(dfx identity get-principal)'", "'${USERNAME}'")'
```

### 2. Create a new post.

```bash
dfx canister call socials createPost '(record {
    postBasics=record {
        title="Ávila Chuao"; 
        tools=opt vec {
            record {"Camera"; "SONY ilce-3000k"}; 
            record {"Lens"; "18-55mm"}
        }; 
        asset="https://www.google.com/url?sa=i&url=https%3A%2F%2Fmiguelev.com%2Funadjustednonraw_thumb_473%2F&psig=AOvVaw1ROuS4UNDW-MVnEx1XORrl&ust=1649854587680000&source=images&cd=vfe&ved=0CAoQjRxqFwoTCLC6n8PJjvcCFQAAAAAdAAAAABAD"; 
        tags=vec {"avila"; "caracas"; "chuao"}; 
        artType="Photography";
        description="Ávila Chuao"; 
        artCategory="Landscape"; 
        details=vec {}
    };
    postImage = vec { 1;2;3 }
})'
```

### Delete a post.

```bash
export POST_ID=$(dfx canister call socials readFirstPostId '(principal "'$(dfx identity get-principal)'")')
dfx canister call socials removePost '('${POST_ID}')'
```

### Follow.

```bash
dfx identity new tester1
export TESTER1_PPAL=$(dfx --identity tester1 identity get-principal)
export TESTER1_USERNAME="ggranado"
dfx --identity tester1 canister call socials relPrincipalWithUsername '(principal "'${TESTER1_PPAL}'", "'${TESTER1_USERNAME}'")'
dfx --identity tester1 canister call socials addFollow '("'${USERNAME}'")'
```

### Check posts by date not only my follows (except mine)

```bash
dfx --identity tester1 canister call socials readPostsByCreation '(1,1)'
```



