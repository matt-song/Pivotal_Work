--
-- Greenplum Database database dump
--

SET gp_default_storage_options = '';
SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: gpss_from_kafka; Type: TABLE; Schema: public; Owner: etl_user; Tablespace: 
--

CREATE TABLE public.gpss_from_kafka (
    id integer,
    c1 text,
    c2 text,
    c3 text,
    c4 text,
    c5 text,
    c6 text,
    c7 text,
    c8 text,
    c9 text,
    c10 text,
    c11 text,
    c12 text,
    c13 text,
    c14 text,
    c15 text
)
 DISTRIBUTED RANDOMLY;


ALTER TABLE public.gpss_from_kafka OWNER TO etl_user;

--
-- Greenplum Database database dump complete
--

