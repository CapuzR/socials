
import Trie "mo:base/Trie";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Bool "mo:base/Bool";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Types "./types";
import Int "mo:base/Int";

module {

    type PostRead = Types.PostRead;

    public func isInDetails (details : [(Text, Types.DetailValue)], v : Text) : Bool {
        for( d in details.vals() ) {
            if( d.0 == v ) {
                return true;
            };
        };
        false;
    };

    public func arrayToBuffer<X>(array : [X]) : Buffer.Buffer<X> {
        let buff : Buffer.Buffer<X> = Buffer.Buffer(array.size() + 2);

        for (a in array.vals()) {
            buff.add(a);
        };
        buff;
    };

    public func key(x : Principal) : Trie.Key<Principal> {
        return { key = x; hash = Principal.hash(x) }
    };

    public func keyText(x : Text) : Trie.Key<Text> {
        return { key = x; hash = Text.hash(x) }
    };

    public func isAuthorized(p : Principal, authorized : [Principal]) : Bool {

        if(Principal.isAnonymous(p)) {
            return false;
        };

        for (a in authorized.vals()) {
            if (Principal.equal(a, p)) {
                return true;
            };
        };
        false;
    };

    public func comparePR(x : PostRead, y : PostRead) : { #less; #equal; #greater } {
        if (Int.less(x.post.createdAt, y.post.createdAt)) { return #greater }
        else if (Int.equal(x.post.createdAt, y.post.createdAt)) { return #equal }
        else { return #less }
    };
}