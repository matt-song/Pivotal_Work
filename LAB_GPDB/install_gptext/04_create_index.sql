CREATE TABLE message (
    id bigint,
    message_id bigint,
    spam boolean,
    created_at timestamp without time zone,
    source text,
    retweeted boolean,
    favorited boolean,
    truncated boolean,
    in_reply_to_screen_name text,
    in_reply_to_user_id bigint,
    author_id bigint,
    author_name text,
    author_screen_name text,
    author_lang text,
    author_url text,
    author_description text,
    author_listed_count integer,
    author_statuses_count integer,
    author_followers_count integer,
    author_friends_count integer,
    author_created_at timestamp without time zone,
    author_location text,
    author_verified boolean,
    message_url text,
    message_text text ) 
DISTRIBUTED BY (id);
--PARTITION BY RANGE (created_at)
--( START (DATE '2011-08-01') INCLUSIVE
--  END (DATE '2011-12-01') EXCLUSIVE
--  EVERY (INTERVAL '1 month'));
CREATE INDEX id_idx ON message USING btree (id);
\COPY message FROM '/data/packages/install_gptext/demo/twitter.csv' CSV;

-- create index
SELECT * FROM gptext.create_index('public','message', 'id', 'message_text');
SELECT * FROM gptext.index(TABLE(SELECT * FROM message), 'demo.public.message');
SELECT * FROM gptext.commit_index('demo.public.message');
