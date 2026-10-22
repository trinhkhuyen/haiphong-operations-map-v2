--
-- PostgreSQL database dump
--

\restrict QJFbsV4GcSdO9WukBvsQOydZnpcLd0XRUvSaTaggTv1IQrGqPQne2oEcx4LtNUr

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.refresh_tokens DROP CONSTRAINT IF EXISTS refresh_tokens_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.monitor_state DROP CONSTRAINT IF EXISTS monitor_state_active_roster_id_fkey;
ALTER TABLE IF EXISTS ONLY public.hnth_rosters DROP CONSTRAINT IF EXISTS hnth_rosters_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.audit_logs DROP CONSTRAINT IF EXISTS audit_logs_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.agent_releases DROP CONSTRAINT IF EXISTS agent_releases_created_by_fkey;
DROP INDEX IF EXISTS public.agents_installation_id_key;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_username_key;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY public.snmp_results DROP CONSTRAINT IF EXISTS snmp_results_pkey;
ALTER TABLE IF EXISTS ONLY public.schema_migrations DROP CONSTRAINT IF EXISTS schema_migrations_pkey;
ALTER TABLE IF EXISTS ONLY public.refresh_tokens DROP CONSTRAINT IF EXISTS refresh_tokens_pkey;
ALTER TABLE IF EXISTS ONLY public.monitor_state DROP CONSTRAINT IF EXISTS monitor_state_pkey;
ALTER TABLE IF EXISTS ONLY public.monitor_logs DROP CONSTRAINT IF EXISTS monitor_logs_pkey;
ALTER TABLE IF EXISTS ONLY public.hnth_rosters DROP CONSTRAINT IF EXISTS hnth_rosters_pkey;
ALTER TABLE IF EXISTS ONLY public.hnth_rosters DROP CONSTRAINT IF EXISTS hnth_rosters_name_key;
ALTER TABLE IF EXISTS ONLY public.hnth_catalog DROP CONSTRAINT IF EXISTS hnth_catalog_pkey;
ALTER TABLE IF EXISTS ONLY public.endpoints DROP CONSTRAINT IF EXISTS endpoints_pkey;
ALTER TABLE IF EXISTS ONLY public.endpoints DROP CONSTRAINT IF EXISTS endpoints_endpoint_id_key;
ALTER TABLE IF EXISTS ONLY public.discovered_ips DROP CONSTRAINT IF EXISTS discovered_ips_pkey;
ALTER TABLE IF EXISTS ONLY public.commands DROP CONSTRAINT IF EXISTS commands_pkey;
ALTER TABLE IF EXISTS ONLY public.audit_logs DROP CONSTRAINT IF EXISTS audit_logs_pkey;
ALTER TABLE IF EXISTS ONLY public.agents DROP CONSTRAINT IF EXISTS agents_pkey;
ALTER TABLE IF EXISTS ONLY public.agents DROP CONSTRAINT IF EXISTS agents_agent_id_key;
ALTER TABLE IF EXISTS ONLY public.agent_update_events DROP CONSTRAINT IF EXISTS agent_update_events_pkey;
ALTER TABLE IF EXISTS ONLY public.agent_releases DROP CONSTRAINT IF EXISTS agent_releases_version_key;
ALTER TABLE IF EXISTS ONLY public.agent_releases DROP CONSTRAINT IF EXISTS agent_releases_pkey;
ALTER TABLE IF EXISTS public.snmp_results ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.monitor_logs ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.audit_logs ALTER COLUMN id DROP DEFAULT;
ALTER TABLE IF EXISTS public.agent_update_events ALTER COLUMN id DROP DEFAULT;
DROP TABLE IF EXISTS public.users;
DROP SEQUENCE IF EXISTS public.snmp_results_id_seq;
DROP TABLE IF EXISTS public.snmp_results;
DROP TABLE IF EXISTS public.schema_migrations;
DROP TABLE IF EXISTS public.refresh_tokens;
DROP TABLE IF EXISTS public.monitor_state;
DROP SEQUENCE IF EXISTS public.monitor_logs_id_seq;
DROP TABLE IF EXISTS public.monitor_logs;
DROP TABLE IF EXISTS public.hnth_rosters;
DROP TABLE IF EXISTS public.hnth_catalog;
DROP TABLE IF EXISTS public.endpoints;
DROP TABLE IF EXISTS public.discovered_ips;
DROP TABLE IF EXISTS public.commands;
DROP SEQUENCE IF EXISTS public.audit_logs_id_seq;
DROP TABLE IF EXISTS public.audit_logs;
DROP TABLE IF EXISTS public.agents;
DROP SEQUENCE IF EXISTS public.agent_update_events_id_seq;
DROP TABLE IF EXISTS public.agent_update_events;
DROP TABLE IF EXISTS public.agent_releases;
DROP EXTENSION IF EXISTS pgcrypto;
--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: agent_releases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_releases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    version text NOT NULL,
    file_name text NOT NULL,
    file_path text NOT NULL,
    sha256 text NOT NULL,
    size_bytes bigint NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agent_update_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_update_events (
    id bigint NOT NULL,
    agent_id text NOT NULL,
    version text NOT NULL,
    status text NOT NULL,
    detail text,
    reported_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: agent_update_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_update_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_update_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_update_events_id_seq OWNED BY public.agent_update_events.id;


--
-- Name: agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agent_id text NOT NULL,
    name text NOT NULL,
    token_hash text NOT NULL,
    status text DEFAULT 'offline'::text NOT NULL,
    last_seen_at timestamp with time zone,
    version text,
    monitor_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    heartbeat_seconds integer DEFAULT 30 NOT NULL,
    machine_id text,
    installation_id text
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id bigint NOT NULL,
    user_id uuid,
    action text NOT NULL,
    resource text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_logs_id_seq OWNED BY public.audit_logs.id;


--
-- Name: commands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commands (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    agent_id text NOT NULL,
    type text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    claimed_at timestamp with time zone
);


--
-- Name: discovered_ips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discovered_ips (
    agent_id text NOT NULL,
    ip_address inet NOT NULL,
    status text DEFAULT 'online'::text NOT NULL,
    mac_address text,
    model_vendor text,
    discovered_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: endpoints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.endpoints (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    endpoint_id text NOT NULL,
    name text NOT NULL,
    ip_address inet,
    model_vendor text,
    status text DEFAULT 'unknown'::text NOT NULL,
    checked_at timestamp with time zone,
    packet_loss_pct numeric,
    jitter_ms numeric,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    latency_ms integer
);


--
-- Name: hnth_catalog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hnth_catalog (
    id integer NOT NULL,
    points jsonb DEFAULT '[]'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hnth_catalog_id_check CHECK ((id = 1))
);


--
-- Name: hnth_rosters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hnth_rosters (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    point_ids jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: monitor_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.monitor_logs (
    id bigint NOT NULL,
    agent_id text NOT NULL,
    endpoint_id text NOT NULL,
    ip_address inet,
    status text NOT NULL,
    latency_ms integer,
    packet_loss_pct numeric,
    jitter_ms numeric,
    checked_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: monitor_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.monitor_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: monitor_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.monitor_logs_id_seq OWNED BY public.monitor_logs.id;


--
-- Name: monitor_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.monitor_state (
    id integer NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    agent_id text DEFAULT 'hnth-haiphong-01'::text NOT NULL,
    concurrency integer DEFAULT 1 NOT NULL,
    wait_seconds integer DEFAULT 3 NOT NULL,
    session_id uuid DEFAULT gen_random_uuid() NOT NULL,
    started_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revision bigint DEFAULT 0 NOT NULL,
    lease_expires_at timestamp with time zone,
    active_roster_id uuid,
    CONSTRAINT monitor_state_id_check CHECK ((id = 1))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refresh_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version integer NOT NULL,
    name text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: snmp_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.snmp_results (
    id bigint NOT NULL,
    agent_id text NOT NULL,
    target_id text NOT NULL,
    host inet NOT NULL,
    oid text NOT NULL,
    value text,
    value_type text,
    checked_at timestamp with time zone NOT NULL,
    received_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: snmp_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.snmp_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: snmp_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.snmp_results_id_seq OWNED BY public.snmp_results.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username text NOT NULL,
    password_hash text NOT NULL,
    display_name text NOT NULL,
    role text NOT NULL,
    menu_permissions jsonb DEFAULT '["layers", "zones", "saved", "routing", "conference", "agents"]'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    department text DEFAULT ''::text NOT NULL,
    phone text DEFAULT ''::text NOT NULL,
    CONSTRAINT users_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'operator'::text, 'viewer'::text])))
);


--
-- Name: agent_update_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_update_events ALTER COLUMN id SET DEFAULT nextval('public.agent_update_events_id_seq'::regclass);


--
-- Name: audit_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs ALTER COLUMN id SET DEFAULT nextval('public.audit_logs_id_seq'::regclass);


--
-- Name: monitor_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monitor_logs ALTER COLUMN id SET DEFAULT nextval('public.monitor_logs_id_seq'::regclass);


--
-- Name: snmp_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snmp_results ALTER COLUMN id SET DEFAULT nextval('public.snmp_results_id_seq'::regclass);


--
-- Data for Name: agent_releases; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.agent_releases (id, version, file_name, file_path, sha256, size_bytes, created_by, created_at) FROM stdin;
06b54d3f-fa68-4b69-8c39-ac5d2c12f082	0.2.1	Agent-HNTH-v0.2.1-Windows-Tray.exe	C:\\Users\\HD5\\Documents\\Claude\\Map\\services\\hnth-backend\\agent-releases\\hnth-agent-0.2.1.exe	a16732063d847299525ef62048c368f343bdd7f41c05c7af88d99f3d2a726a0e	85130944	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	2026-10-21 11:10:44.121703+07
27796b5e-94cc-4095-ac92-29c820dc9367	0.2.4	Agent-HNTH-v0.2.4-Windows-Tray.exe	C:\\Users\\HD5\\Documents\\Claude\\Map\\services\\hnth-backend\\agent-releases\\hnth-agent-0.2.4.exe	f51a4ce1c47d8dc6edaebf19c7ebd37b829613875c4c5eeabca90d213d7fb3d8	85133647	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	2026-10-21 11:20:16.169427+07
f1d0a52d-305f-4ae2-92d8-2d061b0bdcb1	0.2.3	Agent-HNTH-v0.2.3-Windows-Tray.exe	C:\\Users\\HD5\\Documents\\Claude\\Map\\services\\hnth-backend\\agent-releases\\hnth-agent-0.2.3.exe	7e53a255546638ae50a6d3b6969189ce1375de4706c047b885cc633a4409e1a0	85131766	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	2026-10-21 14:32:16.035584+07
a1069afc-3a4e-4b59-9cff-48fe0328226b	0.2.5	Agent-HNTH-v0.2.5-Windows-Tray.exe	C:\\Users\\HD5\\Documents\\Claude\\Map\\services\\hnth-backend\\agent-releases\\hnth-agent-0.2.5.exe	a7af5bf26a95627730cd09529972e17f4e59db86da29ce112425d7bd372a04c4	85137350	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	2026-10-21 19:01:54.709152+07
de6d3b5e-1ce1-444f-8ff0-431d30c5cb21	0.2.6	Agent-HNTH-v0.2.6-Windows-Tray.exe	C:\\Users\\HD5\\Documents\\Claude\\Map\\services\\hnth-backend\\agent-releases\\hnth-agent-0.2.6.exe	922ae8fb2570c26796d44be9df54b9ab0848401b1347c1d3424aa6309b89668d	85144953	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	2026-10-21 19:17:30.496232+07
\.


--
-- Data for Name: agent_update_events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.agent_update_events (id, agent_id, version, status, detail, reported_at) FROM stdin;
5	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	0.2.5	success	Agent 0.2.5 installed at C:\\Users\\HD5\\Documents\\Claude\\Map\\outputs\\hnth-agent-v0.2.4\\Agent-HNTH-v0.2.4-Windows-Tray.exe	2026-10-21 19:02:07.805891+07
6	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	0.2.6	success	Agent 0.2.6 installed at C:\\Users\\HD5\\Documents\\Claude\\Map\\outputs\\hnth-agent-v0.2.4\\Agent-HNTH-v0.2.4-Windows-Tray.exe	2026-10-21 19:17:44.149867+07
\.


--
-- Data for Name: agents; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.agents (id, agent_id, name, token_hash, status, last_seen_at, version, monitor_config, created_at, heartbeat_seconds, machine_id, installation_id) FROM stdin;
8cc0d369-a595-4448-abeb-970e969877d0	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	Agent HNTH - 3050SFF	33070dea0eeb1ed3aac691810a30355b7b1b29a6dbeb50654ac8a5aae96320cf	online	2026-10-22 04:44:51.800783+07	0.2.6	{"points": [{"name": "Trung tâm Chính trị - Hành chính", "pointId": "hnth-hub", "ipAddress": "192.168.1.169", "modelVendor": "Vendor 1"}, {"name": "UBND Ái Quốc", "pointId": "hnth-branch-110", "ipAddress": "192.168.1.159", "modelVendor": "Vendor 2"}, {"name": "UBND An Biên", "pointId": "hnth-branch-13", "ipAddress": "192.168.1.158", "modelVendor": "Vendor 3"}, {"name": "UBND An Dương", "pointId": "hnth-branch-20", "ipAddress": "192.168.1.157", "modelVendor": "Vendor 4"}, {"name": "UBND An Hải", "pointId": "hnth-branch-2", "ipAddress": "192.168.1.156", "modelVendor": "Vendor 5"}, {"name": "UBND An Hưng", "pointId": "hnth-branch-38", "ipAddress": "192.168.1.155", "modelVendor": "Vendor 6"}, {"name": "UBND An Khánh", "pointId": "hnth-branch-35", "ipAddress": "192.168.1.161", "modelVendor": "Vendor 7"}, {"name": "UBND An Lão", "pointId": "hnth-branch-33", "ipAddress": "192.168.1.126", "modelVendor": "Vendor 8"}, {"name": "UBND An Phong", "pointId": "hnth-branch-31", "ipAddress": "192.168.1.125", "modelVendor": "Vendor 9"}, {"name": "UBND An Phú", "pointId": "hnth-branch-89", "ipAddress": "192.168.1.124", "modelVendor": "Vendor 10"}, {"name": "UBND An Quang", "pointId": "hnth-branch-34", "ipAddress": "192.168.1.123", "modelVendor": "Vendor 11"}, {"name": "UBND An Thành", "pointId": "hnth-branch-93", "ipAddress": "192.168.1.122", "modelVendor": "Vendor 12"}, {"name": "UBND An Trường", "pointId": "hnth-branch-32", "ipAddress": "192.168.1.121", "modelVendor": "Vendor 13"}, {"name": "UBND Bạch Đằng", "pointId": "hnth-branch-18", "ipAddress": "192.168.1.120", "modelVendor": "Vendor 14"}, {"name": "UBND Bạch Long Vĩ", "pointId": "hnth-branch-1", "ipAddress": "192.168.1.160", "modelVendor": "Vendor 15"}, {"name": "UBND Bắc An Phụ", "pointId": "hnth-branch-108", "ipAddress": "192.168.1.118", "modelVendor": "Vendor 16"}, {"name": "UBND Bắc Thanh Miện", "pointId": "hnth-branch-42", "ipAddress": "192.168.1.117", "modelVendor": "Vendor 17"}, {"name": "UBND Bình Giang", "pointId": "hnth-branch-62", "ipAddress": "192.168.1.116", "modelVendor": "Vendor 18"}, {"name": "UBND Cát Hải", "pointId": "hnth-branch-69", "ipAddress": "192.168.1.1", "modelVendor": "Cisco"}, {"name": "UBND Cẩm Giàng", "pointId": "hnth-branch-59", "ipAddress": "192.168.1.114", "modelVendor": "Vendor 20"}, {"name": "UBND Cẩm Giang", "pointId": "hnth-branch-64", "ipAddress": "192.168.1.113", "modelVendor": "Vendor 21"}, {"name": "UBND Chấn Hưng", "pointId": "hnth-branch-27", "ipAddress": "192.168.1.112", "modelVendor": "Vendor 22"}, {"name": "UBND Chí Linh", "pointId": "hnth-branch-107", "ipAddress": "192.168.1.111", "modelVendor": "Vendor 23"}, {"name": "UBND Chí Minh", "pointId": "hnth-branch-97", "ipAddress": "192.168.1.110", "modelVendor": "Vendor 24"}, {"name": "UBND Chu Văn An", "pointId": "hnth-branch-106", "ipAddress": "192.168.1.109", "modelVendor": "Vendor 25"}, {"name": "UBND Dương Kinh", "pointId": "hnth-branch-75", "ipAddress": "192.168.1.108", "modelVendor": "Vendor 26"}, {"name": "UBND Đại Sơn", "pointId": "hnth-branch-92", "ipAddress": "192.168.1.107", "modelVendor": "Vendor 27"}, {"name": "UBND Đồ Sơn", "pointId": "hnth-branch-70", "ipAddress": "192.168.1.106", "modelVendor": "Vendor 28"}, {"name": "UBND Đông Hải", "pointId": "hnth-branch-83", "ipAddress": "192.168.1.105", "modelVendor": "Vendor 29"}, {"name": "UBND Đường An", "pointId": "hnth-branch-63", "ipAddress": "192.168.1.104", "modelVendor": "Vendor 30"}, {"name": "UBND Gia Lộc", "pointId": "hnth-branch-68", "ipAddress": "192.168.1.103", "modelVendor": "Vendor 31"}, {"name": "UBND Gia Phúc", "pointId": "hnth-branch-78", "ipAddress": "192.168.1.102", "modelVendor": "Vendor 32"}, {"name": "UBND Gia Viên", "pointId": "hnth-branch-14", "ipAddress": "192.168.1.101", "modelVendor": "Vendor 33"}, {"name": "UBND Hà Bắc", "pointId": "hnth-branch-96", "ipAddress": "192.168.1.100", "modelVendor": "Vendor 34"}, {"name": "UBND Hà Đông", "pointId": "hnth-branch-86", "ipAddress": "192.168.1.99", "modelVendor": "Vendor 35"}, {"name": "UBND Hà Nam", "pointId": "hnth-branch-94", "ipAddress": "192.168.1.98", "modelVendor": "Vendor 36"}, {"name": "UBND Hà Tây", "pointId": "hnth-branch-91", "ipAddress": "192.168.1.97", "modelVendor": "Vendor 37"}, {"name": "UBND Hải An", "pointId": "hnth-branch-11", "ipAddress": "192.168.1.96", "modelVendor": "Vendor 38"}, {"name": "UBND Hải Dương", "pointId": "hnth-branch-85", "ipAddress": "192.168.1.95", "modelVendor": "Vendor 39"}, {"name": "UBND Hải Hưng", "pointId": "hnth-branch-41", "ipAddress": "192.168.1.94", "modelVendor": "Vendor 40"}, {"name": "UBND Hòa Bình", "pointId": "hnth-branch-17", "ipAddress": "192.168.1.93", "modelVendor": "Vendor 41"}, {"name": "UBND Hồng An", "pointId": "hnth-branch-6", "ipAddress": "192.168.1.92", "modelVendor": "Vendor 42"}, {"name": "UBND Hồng Bàng", "pointId": "hnth-branch-15", "ipAddress": "192.168.1.91", "modelVendor": "Vendor 43"}, {"name": "UBND Hồng Châu", "pointId": "hnth-branch-49", "ipAddress": "192.168.1.90", "modelVendor": "Vendor 44"}, {"name": "UBND Hợp Tiến", "pointId": "hnth-branch-104", "ipAddress": "192.168.1.89", "modelVendor": "Vendor 45"}, {"name": "UBND Hưng Đạo", "pointId": "hnth-branch-16", "ipAddress": "192.168.1.87", "modelVendor": "Vendor 47"}, {"name": "UBND Kẻ Sặt", "pointId": "hnth-branch-60", "ipAddress": "192.168.1.86", "modelVendor": "Vendor 48"}, {"name": "UBND Khúc Thừa Dụ", "pointId": "hnth-branch-48", "ipAddress": "192.168.1.85", "modelVendor": "Vendor 49"}, {"name": "UBND Kiến An", "pointId": "hnth-branch-10", "ipAddress": "192.168.1.84", "modelVendor": "Vendor 50"}, {"name": "UBND Kiến Hải", "pointId": "hnth-branch-72", "ipAddress": "192.168.1.83", "modelVendor": "Vendor 51"}, {"name": "UBND Kiến Hưng", "pointId": "hnth-branch-74", "ipAddress": "192.168.1.82", "modelVendor": "Vendor 52"}, {"name": "UBND Kiến Minh", "pointId": "hnth-branch-9", "ipAddress": "192.168.1.81", "modelVendor": "Vendor 53"}, {"name": "UBND Kiến Thụy", "pointId": "hnth-branch-8", "ipAddress": "192.168.1.80", "modelVendor": "Vendor 54"}, {"name": "UBND Kim Thành", "pointId": "hnth-branch-103", "ipAddress": "192.168.1.79", "modelVendor": "Vendor 55"}, {"name": "UBND Kinh Môn", "pointId": "hnth-branch-52", "ipAddress": "192.168.1.78", "modelVendor": "Vendor 56"}, {"name": "UBND Lạc Phượng", "pointId": "hnth-branch-44", "ipAddress": "192.168.1.77", "modelVendor": "Vendor 57"}, {"name": "UBND Lai Khê", "pointId": "hnth-branch-95", "ipAddress": "192.168.1.76", "modelVendor": "Vendor 58"}, {"name": "UBND Lê Chân", "pointId": "hnth-branch-12", "ipAddress": "192.168.1.75", "modelVendor": "Vendor 59"}, {"name": "UBND Lê Đại Hành", "pointId": "hnth-branch-54", "ipAddress": "192.168.1.74", "modelVendor": "Vendor 60"}, {"name": "UBND Lê Ích Mộc", "pointId": "hnth-branch-5", "ipAddress": "192.168.1.73", "modelVendor": "Vendor 61"}, {"name": "UBND Lê Thanh Nghị", "pointId": "hnth-branch-114", "ipAddress": "192.168.1.72", "modelVendor": "Vendor 62"}, {"name": "UBND Lưu Kiếm", "pointId": "hnth-branch-19", "ipAddress": "192.168.1.71", "modelVendor": "Vendor 63"}, {"name": "UBND Mao Điền", "pointId": "hnth-branch-61", "ipAddress": "192.168.1.70", "modelVendor": "Vendor 64"}, {"name": "UBND Nam An Phụ", "pointId": "hnth-branch-90", "ipAddress": "192.168.1.69", "modelVendor": "Vendor 65"}, {"name": "UBND Nam Đồ Sơn", "pointId": "hnth-branch-73", "ipAddress": "192.168.1.68", "modelVendor": "Vendor 66"}, {"name": "UBND Nam Đồng", "pointId": "hnth-branch-67", "ipAddress": "192.168.1.67", "modelVendor": "Vendor 67"}, {"name": "UBND Nam Sách", "pointId": "hnth-branch-76", "ipAddress": "192.168.1.66", "modelVendor": "Vendor 68"}, {"name": "UBND Nam Thanh Miện", "pointId": "hnth-branch-50", "ipAddress": "192.168.1.65", "modelVendor": "Vendor 69"}, {"name": "UBND Nam Triệu", "pointId": "hnth-branch-81", "ipAddress": "192.168.1.64", "modelVendor": "Vendor 70"}, {"name": "UBND Nghi Dương", "pointId": "hnth-branch-39", "ipAddress": "192.168.1.63", "modelVendor": "Vendor 71"}, {"name": "UBND Ngô Quyền", "pointId": "hnth-branch-84", "ipAddress": "192.168.1.62", "modelVendor": "Vendor 72"}, {"name": "UBND Nguyễn Bỉnh Khiêm", "pointId": "hnth-branch-29", "ipAddress": "192.168.1.61", "modelVendor": "Vendor 73"}, {"name": "UBND Nguyễn Đại Năng", "pointId": "hnth-branch-53", "ipAddress": "192.168.1.60", "modelVendor": "Vendor 74"}, {"name": "UBND Nguyên Giáp", "pointId": "hnth-branch-43", "ipAddress": "192.168.1.59", "modelVendor": "Vendor 75"}, {"name": "UBND Nguyễn Lương Bằng", "pointId": "hnth-branch-100", "ipAddress": "192.168.1.58", "modelVendor": "Vendor 76"}, {"name": "UBND Nguyễn Trãi", "pointId": "hnth-branch-57", "ipAddress": "192.168.1.57", "modelVendor": "Vendor 77"}, {"name": "UBND Nhị Chiểu", "pointId": "hnth-branch-109", "ipAddress": "192.168.1.56", "modelVendor": "Vendor 78"}, {"name": "UBND Ninh Giang", "pointId": "hnth-branch-45", "ipAddress": "192.168.1.55", "modelVendor": "Vendor 79"}, {"name": "UBND Phạm Sư Mạnh", "pointId": "hnth-branch-55", "ipAddress": "192.168.1.54", "modelVendor": "Vendor 80"}, {"name": "UBND Phù Liễn", "pointId": "hnth-branch-3", "ipAddress": "192.168.1.53", "modelVendor": "Vendor 81"}, {"name": "UBND Phú Thái", "pointId": "hnth-branch-111", "ipAddress": "192.168.1.52", "modelVendor": "Vendor 82"}, {"name": "UBND Quyết Thắng", "pointId": "hnth-branch-36", "ipAddress": "192.168.1.51", "modelVendor": "Vendor 83"}, {"name": "UBND Tân An", "pointId": "hnth-branch-47", "ipAddress": "192.168.1.50", "modelVendor": "Vendor 84"}, {"name": "UBND Tân Hưng", "pointId": "hnth-branch-77", "ipAddress": "192.168.1.49", "modelVendor": "Vendor 85"}, {"name": "UBND Tân Kỳ", "pointId": "hnth-branch-99", "ipAddress": "192.168.1.48", "modelVendor": "Vendor 86"}, {"name": "UBND Tân Minh", "pointId": "hnth-branch-26", "ipAddress": "192.168.1.47", "modelVendor": "Vendor 87"}, {"name": "UBND Thạch Khôi", "pointId": "hnth-branch-112", "ipAddress": "192.168.1.46", "modelVendor": "Vendor 88"}, {"name": "UBND Thái Tân", "pointId": "hnth-branch-65", "ipAddress": "192.168.1.45", "modelVendor": "Vendor 89"}, {"name": "UBND Thành Đông", "pointId": "hnth-branch-113", "ipAddress": "192.168.1.44", "modelVendor": "Vendor 90"}, {"name": "UBND Thanh Hà", "pointId": "hnth-branch-88", "ipAddress": "192.168.1.43", "modelVendor": "Vendor 91"}, {"name": "UBND Thanh Miện", "pointId": "hnth-branch-102", "ipAddress": "192.168.1.42", "modelVendor": "Vendor 92"}, {"name": "UBND Thiên Hương", "pointId": "hnth-branch-7", "ipAddress": "192.168.1.41", "modelVendor": "Vendor 93"}, {"name": "UBND Thủy Nguyên", "pointId": "hnth-branch-82", "ipAddress": "192.168.1.40", "modelVendor": "Vendor 94"}, {"name": "UBND Thượng Hồng", "pointId": "hnth-branch-51", "ipAddress": "192.168.1.39", "modelVendor": "Vendor 95"}, {"name": "UBND Tiên Lãng", "pointId": "hnth-branch-24", "ipAddress": "192.168.1.38", "modelVendor": "Vendor 96"}, {"name": "UBND Tiên Minh", "pointId": "hnth-branch-25", "ipAddress": "192.168.1.37", "modelVendor": "Vendor 97"}, {"name": "UBND Trần Hưng Đạo", "pointId": "hnth-branch-56", "ipAddress": "192.168.1.36", "modelVendor": "Vendor 98"}, {"name": "UBND Trần Liễu", "pointId": "hnth-branch-87", "ipAddress": "192.168.1.15", "modelVendor": "Vendor 99"}, {"name": "UBND Trần Nhân Tông", "pointId": "hnth-branch-58", "ipAddress": "192.168.1.14", "modelVendor": "Vendor 100"}, {"name": "UBND Trần Phú", "pointId": "hnth-branch-105", "ipAddress": "192.168.1.13", "modelVendor": "Vendor 101"}, {"name": "UBND Trường Tân", "pointId": "hnth-branch-101", "ipAddress": "192.168.1.12", "modelVendor": "Vendor 102"}, {"name": "UBND Tuệ Tĩnh", "pointId": "hnth-branch-79", "ipAddress": "192.168.1.11", "modelVendor": "Vendor 103"}, {"name": "UBND Tứ Kỳ", "pointId": "hnth-branch-98", "ipAddress": "192.168.1.10", "modelVendor": "Vendor 104"}, {"name": "UBND Tứ Minh", "pointId": "hnth-branch-66", "ipAddress": "192.168.1.9", "modelVendor": "Vendor 105"}, {"name": "UBND Việt Hòa", "pointId": "hnth-branch-80", "ipAddress": "192.168.1.8", "modelVendor": "Vendor 106"}, {"name": "UBND Việt Khê", "pointId": "hnth-branch-4", "ipAddress": "192.168.1.7", "modelVendor": "Vendor 107"}, {"name": "UBND Vĩnh Am", "pointId": "hnth-branch-30", "ipAddress": "192.168.1.6", "modelVendor": "Vendor 108"}, {"name": "UBND Vĩnh Bảo", "pointId": "hnth-branch-21", "ipAddress": "192.168.1.5", "modelVendor": "Vendor 109"}, {"name": "UBND Vĩnh Hải", "pointId": "hnth-branch-28", "ipAddress": "192.168.1.4", "modelVendor": "Vendor 110"}, {"name": "UBND Vĩnh Hòa", "pointId": "hnth-branch-23", "ipAddress": "192.168.1.3", "modelVendor": "Vendor 111"}, {"name": "UBND Vĩnh Lại", "pointId": "hnth-branch-46", "ipAddress": "192.168.1.2", "modelVendor": "Vendor 112"}, {"name": "UBND Vĩnh Thịnh", "pointId": "hnth-branch-22", "ipAddress": "192.168.1.135", "modelVendor": "Vendor 113"}, {"name": "UBND Vĩnh Thuận", "pointId": "hnth-branch-37", "ipAddress": "192.168.1.0", "modelVendor": "Vendor 114"}, {"name": "UBND Yết Kiêu", "pointId": "hnth-branch-40", "ipAddress": "192.168.1.16", "modelVendor": "Vendor 115"}, {"name": "Sở Khoa học và Công nghệ", "pointId": "hnth-extra-so-khoa-hoc-va-cong-nghe", "ipAddress": "192.168.1.170", "modelVendor": "Vendor 116"}, {"name": "Sở Văn hóa và Du lịch", "pointId": "hnth-extra-so-van-hoa-va-du-lich", "ipAddress": "192.168.1.171", "modelVendor": "Vendor 117"}, {"name": "Sở Nông nghiệp và Môi trường", "pointId": "hnth-extra-so-nong-nghiep-va-moi-truong", "ipAddress": "192.168.1.172", "modelVendor": "Vendor 118"}, {"name": "Sở Tài chính", "pointId": "hnth-extra-so-tai-chinh", "ipAddress": "192.168.1.173", "modelVendor": "Vendor 119"}, {"name": "Sở Công Thương", "pointId": "hnth-extra-so-cong-thuong", "ipAddress": "192.168.1.174", "modelVendor": "Vendor 120"}, {"name": "Sở Ngoại Vụ", "pointId": "hnth-extra-so-ngoai-vu", "ipAddress": "192.168.1.175", "modelVendor": "Vendor 121"}, {"name": "Sở Nội Vụ", "pointId": "hnth-extra-so-noi-vu", "ipAddress": "192.168.1.176", "modelVendor": "Vendor 122"}, {"name": "Sở Y Tế", "pointId": "hnth-extra-so-y-te", "ipAddress": "192.168.1.177", "modelVendor": "Vendor 123"}, {"name": "Sở Giáo Dục và Đào Tạo", "pointId": "hnth-extra-so-giao-duc-va-dao-tao", "ipAddress": "192.168.1.178", "modelVendor": "Vendor 124"}, {"name": "Ban Quản lý các KKT", "pointId": "hnth-extra-ban-quan-ly-cac-kkt", "ipAddress": "192.168.1.179", "modelVendor": "Vendor 125"}, {"name": "Vườn Quốc Gia Cát Bà", "pointId": "hnth-extra-vuon-quoc-gia-cat-ba", "ipAddress": "192.168.1.180", "modelVendor": "Vendor 126"}], "probeCount": 4, "scanDelayMs": 0, "snmpTargets": [], "probeIntervalMs": 250, "scanConcurrency": 32, "scanScheduleSeconds": 0}	2026-10-21 17:57:53.900981+07	30	2c9a03a2-7c2f-4b6f-911b-0fbe0912b18a	6e2d796252c9c09fb9089dc0b2e29d51
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.audit_logs (id, user_id, action, resource, metadata, created_at) FROM stdin;
1	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	select	hnth-agent	{"agentId": "agent-e91d0d63-f134-42dd-b121-a066cab212f6"}	2026-10-21 11:52:42.567459+07
2	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	select	hnth-agent	{"agentId": "agent-demo"}	2026-10-21 14:29:42.346655+07
3	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	select	hnth-agent	{"agentId": "agent-508b0be9-fed3-4271-8a1f-805bf50fe2da"}	2026-10-21 17:58:39.543182+07
4	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	activate	hnth-roster	{"name": "UBND - Xã/Phường/Đặc khu", "rosterId": "6a125e42-30cb-4092-8069-091e7788bf61"}	2026-10-22 03:08:28.323349+07
5	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	activate	hnth-roster	{"name": "default", "rosterId": null}	2026-10-22 03:10:39.636321+07
6	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	activate	hnth-roster	{"name": "UBND - Xã/Phường/Đặc khu", "rosterId": "6a125e42-30cb-4092-8069-091e7788bf61"}	2026-10-22 03:23:45.533315+07
7	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	activate	hnth-roster	{"name": "default", "rosterId": null}	2026-10-22 03:24:17.889415+07
\.


--
-- Data for Name: discovered_ips; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.discovered_ips (agent_id, ip_address, status, mac_address, model_vendor, discovered_at) FROM stdin;
\.


--
-- Data for Name: endpoints; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.endpoints (id, endpoint_id, name, ip_address, model_vendor, status, checked_at, packet_loss_pct, jitter_ms, enabled, created_at, updated_at, latency_ms) FROM stdin;
46e2ed2f-e650-40c4-be91-d090dfe4a298	hnth-branch-13	UBND An Biên	192.168.1.158	Vendor 3	offline	2026-10-22 04:31:15.41+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:15.414862+07	745
a065cf82-4129-4fa6-b83d-170c7b98bf9c	hnth-branch-20	UBND An Dương	192.168.1.157	Vendor 4	offline	2026-10-22 04:31:15.41+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:15.418597+07	739
1573a204-abb4-4b13-b63b-293d573b7138	hnth-branch-103	UBND Kim Thành	192.168.1.79	Vendor 55	offline	2026-10-22 04:32:44.415+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:44.427239+07	228
efa65704-68a7-4c3c-855c-68237ac02063	hnth-branch-44	UBND Lạc Phượng	192.168.1.77	Vendor 57	offline	2026-10-22 04:32:47.905+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:47.911665+07	223
61d36a3b-0bb5-4a21-8b50-6682a63c66b9	hnth-branch-12	UBND Lê Chân	192.168.1.75	Vendor 59	offline	2026-10-22 04:32:51.401+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:51.405924+07	219
4ff18856-6664-4a61-9321-bc492e17afdb	hnth-branch-54	UBND Lê Đại Hành	192.168.1.74	Vendor 60	offline	2026-10-22 04:32:54.908+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:54.910843+07	242
69048ba8-add7-4b1a-b981-1b9a60a5de33	hnth-branch-5	UBND Lê Ích Mộc	192.168.1.73	Vendor 61	offline	2026-10-22 04:32:54.908+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:54.914601+07	238
52af810a-7dda-40b4-a849-6d1258eedf3a	hnth-branch-114	UBND Lê Thanh Nghị	192.168.1.72	Vendor 62	offline	2026-10-22 04:32:58.411+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:58.413309+07	244
c053c360-b6ce-478a-9000-f58dad784d85	hnth-branch-43	UBND Nguyên Giáp	192.168.1.59	Vendor 75	offline	2026-10-22 04:33:19.415+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:19.432216+07	234
85308630-5fcb-4f74-9446-03282c3b20a8	hnth-branch-57	UBND Nguyễn Trãi	192.168.1.57	Vendor 77	offline	2026-10-22 04:33:22.91+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:22.915621+07	234
d24aff46-4021-4399-aec6-083452065873	hnth-branch-109	UBND Nhị Chiểu	192.168.1.56	Vendor 78	offline	2026-10-22 04:33:26.406+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:26.411002+07	244
c0b40bc5-cb7a-45ce-b146-5c8f7ee9bc33	hnth-branch-45	UBND Ninh Giang	192.168.1.55	Vendor 79	offline	2026-10-22 04:33:26.406+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:26.417957+07	233
dfd0377a-7958-4e84-95e9-c940511fb611	hnth-branch-77	UBND Tân Hưng	192.168.1.49	Vendor 85	online	2026-10-22 04:33:34.368+07	0	10	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:34.384503+07	42
60c69af5-f57a-4d41-a090-f1382e24c917	hnth-branch-56	UBND Trần Hưng Đạo	192.168.1.36	Vendor 98	offline	2026-10-22 04:33:58.902+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:58.905384+07	237
65748e1d-47fd-42d7-9543-a5b7d2de9c53	hnth-branch-87	UBND Trần Liễu	192.168.1.15	Vendor 99	offline	2026-10-22 04:33:58.902+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:58.909834+07	234
464460ae-7c96-457f-8839-be3871e59a04	hnth-branch-101	UBND Trường Tân	192.168.1.12	Vendor 102	offline	2026-10-22 04:34:05.91+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:06.414177+07	243
1896227e-0ea7-440f-8a12-07ac8d3c1abb	hnth-branch-46	UBND Vĩnh Lại	192.168.1.2	Vendor 112	online	2026-10-22 04:34:19.326+07	0	14	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:21.918821+07	37
153c8e27-de3a-4410-862b-85a53e206856	hnth-branch-22	UBND Vĩnh Thịnh	192.168.1.135	Vendor 113	offline	2026-10-22 04:34:21.915+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:21.921775+07	237
d495dd93-9930-4bf3-9d0e-a008d8742dd0	hnth-extra-so-y-te	Sở Y Tế	192.168.1.177	Vendor 123	offline	2026-10-22 04:34:39.415+07	75	0	t	2026-10-22 03:00:27.480173+07	2026-10-22 04:34:39.427925+07	244
b470f902-a7d2-4873-8ce3-937d6ca62a44	hnth-extra-so-giao-duc-va-dao-tao	Sở Giáo Dục và Đào Tạo	192.168.1.178	Vendor 124	offline	2026-10-22 04:34:42.919+07	75	0	t	2026-10-22 03:00:27.480733+07	2026-10-22 04:34:42.921856+07	239
9b618d4d-c03f-4e81-b20c-bf0a84cbea2b	hnth-branch-50	UBND Nam Thanh Miện	192.168.1.65	Vendor 69	offline	2026-10-22 04:33:08.903+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:08.908048+07	237
9e2d49e5-cd4e-4d12-b8d9-162faf4ca36c	hnth-branch-81	UBND Nam Triệu	192.168.1.64	Vendor 70	offline	2026-10-22 04:33:12.413+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:12.416455+07	245
173338dd-ed9c-423d-8b18-881eef3903f3	hnth-branch-110	UBND Ái Quốc	192.168.1.159	Vendor 2	offline	2026-10-22 04:31:11.403+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:11.412261+07	721
377e02a7-e175-4e1f-b61f-a1acd0614999	hnth-branch-2	UBND An Hải	192.168.1.156	Vendor 5	offline	2026-10-22 04:31:19.419+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:19.42317+07	757
bef99dc3-281c-4cce-83c8-bf390797d125	hnth-branch-38	UBND An Hưng	192.168.1.155	Vendor 6	offline	2026-10-22 04:31:19.419+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:19.425611+07	753
491f4215-05bb-4542-b76d-2ccd0354aef9	hnth-branch-35	UBND An Khánh	192.168.1.161	Vendor 7	offline	2026-10-22 04:31:23.41+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:23.413778+07	743
dd228f0f-6a7d-4d8a-b0b1-d10b9ca2dcb1	hnth-branch-39	UBND Nghi Dương	192.168.1.63	Vendor 71	offline	2026-10-22 04:33:12.413+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:12.41866+07	199
2457be70-d675-4b34-94e4-5949af4e259f	hnth-branch-33	UBND An Lão	192.168.1.126	Vendor 8	offline	2026-10-22 04:31:23.409+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:23.418061+07	739
0cbf6aa0-4b1b-4fbf-94bf-0c079630ada6	hnth-branch-84	UBND Ngô Quyền	192.168.1.62	Vendor 72	offline	2026-10-22 04:33:15.906+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:15.910412+07	259
91d4ead5-5f43-4514-a673-05de3fc1a519	hnth-branch-29	UBND Nguyễn Bỉnh Khiêm	192.168.1.61	Vendor 73	offline	2026-10-22 04:33:15.905+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:15.915229+07	253
fa622e86-9157-43ee-95d6-95b00f4bffbe	hnth-branch-55	UBND Phạm Sư Mạnh	192.168.1.54	Vendor 80	offline	2026-10-22 04:33:29.907+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:29.910067+07	227
6bcde808-dc18-48d6-a483-8e2273a125cc	hnth-branch-3	UBND Phù Liễn	192.168.1.53	Vendor 81	offline	2026-10-22 04:33:29.907+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:29.912401+07	234
c8ff5953-f6b9-45a6-8f63-bcf1ebcf890f	hnth-branch-111	UBND Phú Thái	192.168.1.52	Vendor 82	online	2026-10-22 04:33:30.917+07	0	14.33	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:33.407542+07	56
440796df-48a9-48cb-bcb1-09dc8067a04d	hnth-branch-36	UBND Quyết Thắng	192.168.1.51	Vendor 83	offline	2026-10-22 04:33:33.404+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:33.409733+07	238
bf2a76d0-384d-4f71-a7a3-4e29ee23f799	hnth-branch-47	UBND Tân An	192.168.1.50	Vendor 84	online	2026-10-22 04:33:34.38+07	0	13	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:34.382715+07	45
ba92969f-f6b9-4c7f-a8ee-8905520a90eb	hnth-branch-99	UBND Tân Kỳ	192.168.1.48	Vendor 86	offline	2026-10-22 04:33:37.901+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:37.904963+07	229
38108cca-69ca-4d05-8393-adec014ada2a	hnth-branch-31	UBND An Phong	192.168.1.125	Vendor 9	offline	2026-10-22 04:31:27.404+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:27.408761+07	737
b4c557ec-f836-478e-b985-792b63847cf6	hnth-branch-89	UBND An Phú	192.168.1.124	Vendor 10	offline	2026-10-22 04:31:26.904+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:27.413458+07	236
2e53635e-1a22-4cc2-a262-68c647f8cf38	hnth-branch-26	UBND Tân Minh	192.168.1.47	Vendor 87	offline	2026-10-22 04:33:37.901+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:37.907479+07	226
eb9bee6a-262d-4fe1-acb3-6db55d9d126e	hnth-branch-34	UBND An Quang	192.168.1.123	Vendor 11	offline	2026-10-22 04:31:30.913+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:30.91633+07	217
57618436-03f9-4840-b7c2-85ba4cc52f54	hnth-branch-106	UBND Chu Văn An	192.168.1.109	Vendor 25	offline	2026-10-22 04:31:55.408+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:55.411402+07	228
5183721c-9ca1-4a48-9ecd-b4f416330af4	hnth-branch-17	UBND Hòa Bình	192.168.1.93	Vendor 41	offline	2026-10-22 04:32:23.42+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:23.425454+07	243
6e336adf-0910-48b7-9f48-ee1abcc16992	hnth-branch-15	UBND Hồng Bàng	192.168.1.91	Vendor 43	offline	2026-10-22 04:32:26.91+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:26.914133+07	227
817626cf-990c-4ee1-aa9f-4f3df48e893c	hnth-branch-104	UBND Hợp Tiến	192.168.1.89	Vendor 45	offline	2026-10-22 04:32:30.42+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:30.425614+07	241
8c2db61a-64c0-4f2b-9e5d-0375dfbba635	hnth-branch-16	UBND Hưng Đạo	192.168.1.87	Vendor 47	offline	2026-10-22 04:32:30.42+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:30.432435+07	229
574a8a5d-4261-4001-85a5-99f0d6de79d4	hnth-branch-52	UBND Kinh Môn	192.168.1.78	Vendor 56	offline	2026-10-22 04:32:47.905+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:47.908235+07	227
650b3d04-a5bc-4656-9f5d-a718c4005298	hnth-branch-19	UBND Lưu Kiếm	192.168.1.71	Vendor 63	offline	2026-10-22 04:32:58.411+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:58.416146+07	195
fe4a368f-d067-4d9f-b4c8-4a9f05295d19	hnth-hub	Trung tâm Chính trị - Hành chính	192.168.1.169	Vendor 1	offline	2026-10-22 04:41:48.408+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:41:48.412789+07	240
fc592421-e536-4374-a8b3-e0c96b208196	hnth-branch-73	UBND Nam Đồ Sơn	192.168.1.68	Vendor 66	offline	2026-10-22 04:33:05.403+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:05.404949+07	242
dd5f7b33-1304-424f-9bb4-09fc12634ee0	hnth-branch-67	UBND Nam Đồng	192.168.1.67	Vendor 67	offline	2026-10-22 04:33:05.403+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:05.40708+07	202
2b048634-c59e-47af-afc6-c150d7bd4fa9	hnth-branch-76	UBND Nam Sách	192.168.1.66	Vendor 68	offline	2026-10-22 04:33:08.903+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:08.905734+07	240
f623a01a-b606-4121-9aa3-a2f9c0e8cf64	hnth-branch-75	UBND Dương Kinh	192.168.1.108	Vendor 26	offline	2026-10-22 04:31:55.408+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:55.416599+07	241
90591b08-b7bc-45f1-8850-dd8293ac5538	hnth-branch-92	UBND Đại Sơn	192.168.1.107	Vendor 27	offline	2026-10-22 04:31:58.919+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:58.924217+07	234
af730745-571e-449d-a407-32f93d794677	hnth-branch-70	UBND Đồ Sơn	192.168.1.106	Vendor 28	offline	2026-10-22 04:31:58.919+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:58.930227+07	243
c7b64dc8-d5d2-492d-adcd-377c5a51d182	hnth-branch-83	UBND Đông Hải	192.168.1.105	Vendor 29	offline	2026-10-22 04:32:02.403+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:02.405806+07	241
4353426b-23c4-42f1-b503-952c72892f57	hnth-branch-63	UBND Đường An	192.168.1.104	Vendor 30	offline	2026-10-22 04:32:02.403+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:02.407789+07	230
17904204-065d-4c7a-82fb-6a67e4e9fe8c	hnth-branch-68	UBND Gia Lộc	192.168.1.103	Vendor 31	offline	2026-10-22 04:32:05.909+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:05.912092+07	245
2a0aa2a2-f65a-4a1a-bf91-870e4d1f05c4	hnth-branch-78	UBND Gia Phúc	192.168.1.102	Vendor 32	offline	2026-10-22 04:32:05.909+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:05.915026+07	243
ea67c38d-63f9-44e7-b445-b666cf365e6e	hnth-branch-96	UBND Hà Bắc	192.168.1.100	Vendor 34	offline	2026-10-22 04:32:09.404+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:09.414534+07	233
d62b0a97-7ebc-42df-b52b-17d5b6ca5633	hnth-branch-86	UBND Hà Đông	192.168.1.99	Vendor 35	offline	2026-10-22 04:32:12.919+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:12.924445+07	244
2fa8db67-ea2a-4d6f-a533-ee809376d7e6	hnth-branch-94	UBND Hà Nam	192.168.1.98	Vendor 36	offline	2026-10-22 04:32:12.919+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:12.930128+07	239
84c5faa2-6e69-41a7-9875-46f036822e3d	hnth-branch-91	UBND Hà Tây	192.168.1.97	Vendor 37	offline	2026-10-22 04:32:16.409+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:16.413097+07	242
093e4ab5-791f-49b7-8138-72f8276e5db8	hnth-branch-85	UBND Hải Dương	192.168.1.95	Vendor 39	offline	2026-10-22 04:32:19.903+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:19.907521+07	241
22bb2bfd-f0ec-49b8-a10a-f0aea92ad0ab	hnth-branch-112	UBND Thạch Khôi	192.168.1.46	Vendor 88	offline	2026-10-22 04:33:41.413+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:41.416312+07	243
64e49ad0-c925-4a21-87d0-ea79d7977e98	hnth-extra-vuon-quoc-gia-cat-ba	Vườn Quốc Gia Cát Bà	192.168.1.180	Vendor 126	offline	2026-10-22 04:34:46.399+07	75	0	t	2026-10-22 03:00:27.481603+07	2026-10-22 04:34:46.410923+07	237
f5cb61e2-3291-445e-918d-4ecca7bb4b13	hnth-branch-6	UBND Hồng An	192.168.1.92	Vendor 42	offline	2026-10-22 04:32:23.419+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:23.433291+07	233
2fbb621f-9a61-451c-a742-f1b1ab6955dc	hnth-branch-49	UBND Hồng Châu	192.168.1.90	Vendor 44	offline	2026-10-22 04:32:26.91+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:26.917748+07	220
4785b267-6219-4705-be78-f02c8edf1992	hnth-branch-60	UBND Kẻ Sặt	192.168.1.86	Vendor 48	offline	2026-10-22 04:32:33.917+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:33.920659+07	224
94199bfb-a75b-4443-8ac1-50f142503240	hnth-branch-72	UBND Kiến Hải	192.168.1.83	Vendor 51	offline	2026-10-22 04:32:37.404+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:37.409545+07	238
c2f99ae4-e704-4226-b034-081036b5a5a9	hnth-branch-74	UBND Kiến Hưng	192.168.1.82	Vendor 52	offline	2026-10-22 04:32:40.904+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:40.908428+07	238
0ca1d746-ea22-48d8-adb6-eb73f42b0f2c	hnth-branch-9	UBND Kiến Minh	192.168.1.81	Vendor 53	offline	2026-10-22 04:32:40.904+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:40.912923+07	242
2994e18c-1e28-4e8d-b568-1025633637d7	hnth-branch-8	UBND Kiến Thụy	192.168.1.80	Vendor 54	offline	2026-10-22 04:32:44.415+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:44.420937+07	239
cd20121b-3430-4f04-af2d-39d5bd5e3f60	hnth-branch-95	UBND Lai Khê	192.168.1.76	Vendor 58	offline	2026-10-22 04:32:51.401+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:51.403636+07	230
040ed9a6-5bf6-4f00-97bc-66a79752edac	hnth-branch-61	UBND Mao Điền	192.168.1.70	Vendor 64	offline	2026-10-22 04:33:01.914+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:01.918274+07	237
9abca4d0-c560-431d-8c5e-2f6a9da9f8e5	hnth-branch-90	UBND Nam An Phụ	192.168.1.69	Vendor 65	offline	2026-10-22 04:33:01.914+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:01.921695+07	240
1e768dff-f7f3-477d-9710-0c74166acd89	hnth-branch-53	UBND Nguyễn Đại Năng	192.168.1.60	Vendor 74	offline	2026-10-22 04:33:19.415+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:19.423333+07	244
75c835cc-54d1-40b4-a780-ea7f0355b73d	hnth-branch-14	UBND Gia Viên	192.168.1.101	Vendor 33	offline	2026-10-22 04:32:09.404+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:09.407997+07	245
fbd8acfc-e7bc-41ef-82fc-535f98d23775	hnth-branch-11	UBND Hải An	192.168.1.96	Vendor 38	offline	2026-10-22 04:32:16.409+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:16.417125+07	232
bc7dc5fa-fc25-4ea6-87c1-66dbfa337d9a	hnth-branch-41	UBND Hải Hưng	192.168.1.94	Vendor 40	offline	2026-10-22 04:32:19.903+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:19.911418+07	245
b36eae53-44f8-4afe-9231-0394fa28e27e	hnth-branch-71	UBND Hùng Thắng	\N	Vendor 46	unknown	\N	\N	\N	t	2026-10-21 00:29:12.359725+07	2026-10-22 03:24:17.831036+07	\N
3debbec3-75b9-402f-9109-9bca4f464d81	hnth-branch-48	UBND Khúc Thừa Dụ	192.168.1.85	Vendor 49	offline	2026-10-22 04:32:33.917+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:33.924082+07	228
0f49ae31-23db-43e7-a1c6-c61df8c8c842	hnth-branch-10	UBND Kiến An	192.168.1.84	Vendor 50	offline	2026-10-22 04:32:37.404+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:32:37.406618+07	226
2709829a-b825-4dec-8f02-9f8b6338b395	hnth-branch-65	UBND Thái Tân	192.168.1.45	Vendor 89	offline	2026-10-22 04:33:41.413+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:41.41836+07	233
622b345e-4658-4caf-8894-cd585e49fcd0	hnth-branch-113	UBND Thành Đông	192.168.1.44	Vendor 90	offline	2026-10-22 04:33:44.908+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:44.911206+07	243
3f1e533a-6ed4-4ab5-a3bf-f37cbc602ae2	hnth-branch-58	UBND Trần Nhân Tông	192.168.1.14	Vendor 100	offline	2026-10-22 04:34:02.4+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:02.403349+07	241
c651f541-30fd-4461-b1c2-cf1a2d45f99f	hnth-branch-105	UBND Trần Phú	192.168.1.13	Vendor 101	offline	2026-10-22 04:34:02.4+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:02.40547+07	229
67a0811c-2702-486f-a7c0-7ef4985d6996	hnth-branch-37	UBND Vĩnh Thuận	192.168.1.0	Vendor 114	offline	2026-10-22 04:34:25.401+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:25.404601+07	244
82bb3ccd-8d7a-4b50-b646-5e5fe54600cd	hnth-branch-40	UBND Yết Kiêu	192.168.1.16	Vendor 115	offline	2026-10-22 04:34:25.402+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:25.406581+07	254
f40933bf-bdc1-4e6e-936d-9f3489e6dda6	hnth-extra-so-khoa-hoc-va-cong-nghe	Sở Khoa học và Công nghệ	192.168.1.170	Vendor 116	offline	2026-10-22 04:34:28.906+07	75	0	t	2026-10-22 03:00:27.467297+07	2026-10-22 04:34:28.911962+07	242
9062ea19-7790-4788-bb63-7d48ad94a41e	hnth-extra-so-van-hoa-va-du-lich	Sở Văn hóa và Du lịch	192.168.1.171	Vendor 117	offline	2026-10-22 04:34:28.906+07	75	0	t	2026-10-22 03:00:27.47614+07	2026-10-22 04:34:28.917525+07	238
135dd33e-09cf-47c6-a782-f12794587c75	hnth-extra-so-nong-nghiep-va-moi-truong	Sở Nông nghiệp và Môi trường	192.168.1.172	Vendor 118	offline	2026-10-22 04:34:32.412+07	75	0	t	2026-10-22 03:00:27.47712+07	2026-10-22 04:34:32.417305+07	232
2c805202-880d-4cfa-92ff-5a41a998d8cd	hnth-branch-93	UBND An Thành	192.168.1.122	Vendor 12	offline	2026-10-22 04:31:30.913+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:30.918767+07	221
e1ac9569-7765-4dfa-932b-6d9fc82005d9	hnth-branch-32	UBND An Trường	192.168.1.121	Vendor 13	offline	2026-10-22 04:31:34.409+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:34.41274+07	238
95f8d1a5-0b2d-4c82-9d81-3c16e55b0d54	hnth-branch-18	UBND Bạch Đằng	192.168.1.120	Vendor 14	offline	2026-10-22 04:31:34.409+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:34.416756+07	227
b63234fe-b82f-4ffd-8338-fdf5452631d6	hnth-branch-1	UBND Bạch Long Vĩ	192.168.1.160	Vendor 15	online	2026-10-22 04:31:35.439+07	0	7	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:37.915183+07	58
95b7cd9e-f338-4ffc-ba4d-00c36e73500c	hnth-branch-108	UBND Bắc An Phụ	192.168.1.118	Vendor 16	offline	2026-10-22 04:31:37.91+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:37.921985+07	241
1323b4dc-0f01-47a1-bc4c-52b681a83571	hnth-branch-42	UBND Bắc Thanh Miện	192.168.1.117	Vendor 17	offline	2026-10-22 04:31:41.413+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:41.41734+07	242
092f3138-8ae7-4e0a-a433-9bff1a8c250b	hnth-branch-62	UBND Bình Giang	192.168.1.116	Vendor 18	offline	2026-10-22 04:31:41.413+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:41.421856+07	230
64c633a9-9deb-44f0-9921-5ceb6ec1dea9	hnth-branch-69	UBND Cát Hải	192.168.1.1	Cisco	online	2026-10-22 04:31:42.482+07	0	24.33	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:44.91154+07	66
d39e0543-d545-4281-9b95-f643107db61c	hnth-branch-59	UBND Cẩm Giàng	192.168.1.114	Vendor 20	offline	2026-10-22 04:31:44.906+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:44.918795+07	243
0cf4c124-9095-4877-a1ec-9add558a3600	hnth-branch-64	UBND Cẩm Giang	192.168.1.113	Vendor 21	offline	2026-10-22 04:31:48.405+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:48.411281+07	235
0e4bf578-1322-4633-8259-f4bafbc93b65	hnth-branch-27	UBND Chấn Hưng	192.168.1.112	Vendor 22	offline	2026-10-22 04:31:48.405+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:48.419449+07	246
b82b91c0-b208-46a3-b2e1-82249f92b458	hnth-branch-107	UBND Chí Linh	192.168.1.111	Vendor 23	offline	2026-10-22 04:31:51.911+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:51.916022+07	242
bcd90292-3b35-4ae7-82e7-62543ce4f79f	hnth-branch-97	UBND Chí Minh	192.168.1.110	Vendor 24	offline	2026-10-22 04:31:51.911+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:31:51.920352+07	238
e5848837-ea89-4f95-b790-718ed49d10eb	hnth-extra-so-tai-chinh	Sở Tài chính	192.168.1.173	Vendor 119	offline	2026-10-22 04:34:32.412+07	75	0	t	2026-10-22 03:00:27.477848+07	2026-10-22 04:34:32.421642+07	238
2f771cbb-585c-4e8b-99cc-4407ba7f3c6f	hnth-extra-so-cong-thuong	Sở Công Thương	192.168.1.174	Vendor 120	offline	2026-10-22 04:34:35.915+07	75	0	t	2026-10-22 03:00:27.478535+07	2026-10-22 04:34:35.91742+07	242
a3212b11-69bd-41f3-a90f-8daff5f99dda	hnth-extra-so-ngoai-vu	Sở Ngoại Vụ	192.168.1.175	Vendor 121	offline	2026-10-22 04:34:35.915+07	75	0	t	2026-10-22 03:00:27.478989+07	2026-10-22 04:34:35.919354+07	236
24b73936-3bf5-4986-8796-18e9a74900b8	hnth-extra-so-noi-vu	Sở Nội Vụ	192.168.1.176	Vendor 122	offline	2026-10-22 04:34:39.415+07	75	0	t	2026-10-22 03:00:27.479581+07	2026-10-22 04:34:39.42024+07	236
50ecb619-514e-4f79-853c-b87f6970cd88	hnth-branch-100	UBND Nguyễn Lương Bằng	192.168.1.58	Vendor 76	offline	2026-10-22 04:33:22.91+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:22.91349+07	238
26c74242-120f-402a-83b5-a3b6e5b2a80b	hnth-branch-88	UBND Thanh Hà	192.168.1.43	Vendor 91	offline	2026-10-22 04:33:44.908+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:44.913737+07	239
73d80c56-217d-4fce-be8a-e0d0ac43c1b3	hnth-branch-102	UBND Thanh Miện	192.168.1.42	Vendor 92	offline	2026-10-22 04:33:48.415+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:48.420864+07	239
2340952d-c048-43e8-ad17-0ef03ec02142	hnth-branch-7	UBND Thiên Hương	192.168.1.41	Vendor 93	offline	2026-10-22 04:33:48.415+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:48.426293+07	242
2009f58b-fcd2-4c1c-bdaa-f5952cf7fe2b	hnth-branch-82	UBND Thủy Nguyên	192.168.1.40	Vendor 94	offline	2026-10-22 04:33:51.904+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:51.908395+07	235
3ab2d293-1ff6-48b0-b139-c270912bbb18	hnth-branch-51	UBND Thượng Hồng	192.168.1.39	Vendor 95	offline	2026-10-22 04:33:51.904+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:51.912082+07	239
529308b4-db36-46f2-9b7a-5ecd502c600e	hnth-branch-24	UBND Tiên Lãng	192.168.1.38	Vendor 96	offline	2026-10-22 04:33:55.414+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:55.42004+07	238
c214a14f-4e76-4877-8b69-e3342fc87a4e	hnth-branch-25	UBND Tiên Minh	192.168.1.37	Vendor 97	offline	2026-10-22 04:33:55.414+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:33:55.426613+07	231
856f48b1-d167-48f6-9b7c-8b3ad1db6270	hnth-branch-98	UBND Tứ Kỳ	192.168.1.10	Vendor 104	offline	2026-10-22 04:34:09.907+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:09.913386+07	235
8d49fefb-6f2a-4941-a0c5-11c0158a22b9	hnth-branch-66	UBND Tứ Minh	192.168.1.9	Vendor 105	offline	2026-10-22 04:34:09.906+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:09.919995+07	231
6337db16-4408-4cd8-96c2-8ffdc4a919eb	hnth-branch-80	UBND Việt Hòa	192.168.1.8	Vendor 106	offline	2026-10-22 04:34:13.907+07	100	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:13.910991+07	\N
41440c77-a7df-4367-b740-f39b72847b21	hnth-branch-4	UBND Việt Khê	192.168.1.7	Vendor 107	online	2026-10-22 04:34:11.067+07	0	45.33	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:13.914967+07	92
1ed03800-fe35-44fd-8f14-15b0113a8cf0	hnth-branch-30	UBND Vĩnh Am	192.168.1.6	Vendor 108	online	2026-10-22 04:34:14.848+07	0	3	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:14.853936+07	36
85e24b99-17ff-495e-b59c-89fe4ac24f50	hnth-branch-21	UBND Vĩnh Bảo	192.168.1.5	Vendor 109	online	2026-10-22 04:34:14.851+07	0	2.33	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:14.855813+07	33
0dcfa2cf-5d1c-4ce1-95e8-483804b95aff	hnth-branch-28	UBND Vĩnh Hải	192.168.1.4	Vendor 110	online	2026-10-22 04:34:15.817+07	0	8.67	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:18.402337+07	49
85a6961f-7408-4c3f-aa7e-70c067a9f3f2	hnth-branch-23	UBND Vĩnh Hòa	192.168.1.3	Vendor 111	offline	2026-10-22 04:34:18.399+07	75	0	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:34:18.404888+07	240
9bbc364d-ad7d-4405-b20e-8c499999cc47	hnth-extra-ban-quan-ly-cac-kkt	Ban Quản lý các KKT	192.168.1.179	Vendor 125	offline	2026-10-22 04:34:42.919+07	75	0	t	2026-10-22 03:00:27.481196+07	2026-10-22 04:34:42.931707+07	245
313439bb-8349-40d1-bcfa-b6d245551529	hnth-branch-79	UBND Tuệ Tĩnh	192.168.1.11	Vendor 103	online	2026-10-22 04:44:37.105+07	0	44.33	t	2026-10-21 00:28:55.467113+07	2026-10-22 04:44:39.419945+07	102
\.


--
-- Data for Name: hnth_catalog; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.hnth_catalog (id, points, updated_at) FROM stdin;
1	[{"kind": "hub", "name": "Trung tâm Chính trị - Hành chính", "gateway": "192.168.1.1", "pointId": "hnth-hub", "ipAddress": "192.168.1.169", "modelVendor": "Vendor 1"}, {"kind": "ward", "name": "UBND Ái Quốc", "gateway": "192.168.1.1", "pointId": "hnth-branch-110", "ipAddress": "192.168.1.159", "modelVendor": "Vendor 2"}, {"kind": "ward", "name": "UBND An Biên", "gateway": "192.168.1.1", "pointId": "hnth-branch-13", "ipAddress": "192.168.1.158", "modelVendor": "Vendor 3"}, {"kind": "ward", "name": "UBND An Dương", "gateway": "192.168.1.1", "pointId": "hnth-branch-20", "ipAddress": "192.168.1.157", "modelVendor": "Vendor 4"}, {"kind": "ward", "name": "UBND An Hải", "gateway": "192.168.1.1", "pointId": "hnth-branch-2", "ipAddress": "192.168.1.156", "modelVendor": "Vendor 5"}, {"kind": "ward", "name": "UBND An Hưng", "gateway": "192.168.1.1", "pointId": "hnth-branch-38", "ipAddress": "192.168.1.155", "modelVendor": "Vendor 6"}, {"kind": "ward", "name": "UBND An Khánh", "gateway": "192.168.1.1", "pointId": "hnth-branch-35", "ipAddress": "192.168.1.161", "modelVendor": "Vendor 7"}, {"kind": "ward", "name": "UBND An Lão", "gateway": "192.168.1.1", "pointId": "hnth-branch-33", "ipAddress": "192.168.1.126", "modelVendor": "Vendor 8"}, {"kind": "ward", "name": "UBND An Phong", "gateway": "192.168.1.1", "pointId": "hnth-branch-31", "ipAddress": "192.168.1.125", "modelVendor": "Vendor 9"}, {"kind": "ward", "name": "UBND An Phú", "gateway": "192.168.1.1", "pointId": "hnth-branch-89", "ipAddress": "192.168.1.124", "modelVendor": "Vendor 10"}, {"kind": "ward", "name": "UBND An Quang", "gateway": "192.168.1.1", "pointId": "hnth-branch-34", "ipAddress": "192.168.1.123", "modelVendor": "Vendor 11"}, {"kind": "ward", "name": "UBND An Thành", "gateway": "192.168.1.1", "pointId": "hnth-branch-93", "ipAddress": "192.168.1.122", "modelVendor": "Vendor 12"}, {"kind": "ward", "name": "UBND An Trường", "gateway": "192.168.1.1", "pointId": "hnth-branch-32", "ipAddress": "192.168.1.121", "modelVendor": "Vendor 13"}, {"kind": "ward", "name": "UBND Bạch Đằng", "gateway": "192.168.1.1", "pointId": "hnth-branch-18", "ipAddress": "192.168.1.120", "modelVendor": "Vendor 14"}, {"kind": "ward", "name": "UBND Bạch Long Vĩ", "gateway": "192.168.1.1", "pointId": "hnth-branch-1", "ipAddress": "192.168.1.160", "modelVendor": "Vendor 15"}, {"kind": "ward", "name": "UBND Bắc An Phụ", "gateway": "192.168.1.1", "pointId": "hnth-branch-108", "ipAddress": "192.168.1.118", "modelVendor": "Vendor 16"}, {"kind": "ward", "name": "UBND Bắc Thanh Miện", "gateway": "192.168.1.1", "pointId": "hnth-branch-42", "ipAddress": "192.168.1.117", "modelVendor": "Vendor 17"}, {"kind": "ward", "name": "UBND Bình Giang", "gateway": "192.168.1.1", "pointId": "hnth-branch-62", "ipAddress": "192.168.1.116", "modelVendor": "Vendor 18"}, {"kind": "ward", "name": "UBND Cát Hải", "gateway": "192.168.1.1", "pointId": "hnth-branch-69", "ipAddress": "192.168.1.1", "modelVendor": "Cisco"}, {"kind": "ward", "name": "UBND Cẩm Giàng", "gateway": "192.168.1.1", "pointId": "hnth-branch-59", "ipAddress": "192.168.1.114", "modelVendor": "Vendor 20"}, {"kind": "ward", "name": "UBND Cẩm Giang", "gateway": "192.168.1.1", "pointId": "hnth-branch-64", "ipAddress": "192.168.1.113", "modelVendor": "Vendor 21"}, {"kind": "ward", "name": "UBND Chấn Hưng", "gateway": "192.168.1.1", "pointId": "hnth-branch-27", "ipAddress": "192.168.1.112", "modelVendor": "Vendor 22"}, {"kind": "ward", "name": "UBND Chí Linh", "gateway": "192.168.1.1", "pointId": "hnth-branch-107", "ipAddress": "192.168.1.111", "modelVendor": "Vendor 23"}, {"kind": "ward", "name": "UBND Chí Minh", "gateway": "192.168.1.1", "pointId": "hnth-branch-97", "ipAddress": "192.168.1.110", "modelVendor": "Vendor 24"}, {"kind": "ward", "name": "UBND Chu Văn An", "gateway": "192.168.1.1", "pointId": "hnth-branch-106", "ipAddress": "192.168.1.109", "modelVendor": "Vendor 25"}, {"kind": "ward", "name": "UBND Dương Kinh", "gateway": "192.168.1.1", "pointId": "hnth-branch-75", "ipAddress": "192.168.1.108", "modelVendor": "Vendor 26"}, {"kind": "ward", "name": "UBND Đại Sơn", "gateway": "192.168.1.1", "pointId": "hnth-branch-92", "ipAddress": "192.168.1.107", "modelVendor": "Vendor 27"}, {"kind": "ward", "name": "UBND Đồ Sơn", "gateway": "192.168.1.1", "pointId": "hnth-branch-70", "ipAddress": "192.168.1.106", "modelVendor": "Vendor 28"}, {"kind": "ward", "name": "UBND Đông Hải", "gateway": "192.168.1.1", "pointId": "hnth-branch-83", "ipAddress": "192.168.1.105", "modelVendor": "Vendor 29"}, {"kind": "ward", "name": "UBND Đường An", "gateway": "192.168.1.1", "pointId": "hnth-branch-63", "ipAddress": "192.168.1.104", "modelVendor": "Vendor 30"}, {"kind": "ward", "name": "UBND Gia Lộc", "gateway": "192.168.1.1", "pointId": "hnth-branch-68", "ipAddress": "192.168.1.103", "modelVendor": "Vendor 31"}, {"kind": "ward", "name": "UBND Gia Phúc", "gateway": "192.168.1.1", "pointId": "hnth-branch-78", "ipAddress": "192.168.1.102", "modelVendor": "Vendor 32"}, {"kind": "ward", "name": "UBND Gia Viên", "gateway": "192.168.1.1", "pointId": "hnth-branch-14", "ipAddress": "192.168.1.101", "modelVendor": "Vendor 33"}, {"kind": "ward", "name": "UBND Hà Bắc", "gateway": "192.168.1.1", "pointId": "hnth-branch-96", "ipAddress": "192.168.1.100", "modelVendor": "Vendor 34"}, {"kind": "ward", "name": "UBND Hà Đông", "gateway": "192.168.1.1", "pointId": "hnth-branch-86", "ipAddress": "192.168.1.99", "modelVendor": "Vendor 35"}, {"kind": "ward", "name": "UBND Hà Nam", "gateway": "192.168.1.1", "pointId": "hnth-branch-94", "ipAddress": "192.168.1.98", "modelVendor": "Vendor 36"}, {"kind": "ward", "name": "UBND Hà Tây", "gateway": "192.168.1.1", "pointId": "hnth-branch-91", "ipAddress": "192.168.1.97", "modelVendor": "Vendor 37"}, {"kind": "ward", "name": "UBND Hải An", "gateway": "192.168.1.1", "pointId": "hnth-branch-11", "ipAddress": "192.168.1.96", "modelVendor": "Vendor 38"}, {"kind": "ward", "name": "UBND Hải Dương", "gateway": "192.168.1.1", "pointId": "hnth-branch-85", "ipAddress": "192.168.1.95", "modelVendor": "Vendor 39"}, {"kind": "ward", "name": "UBND Hải Hưng", "gateway": "10.33.1.1", "pointId": "hnth-branch-41", "ipAddress": "192.168.1.94", "modelVendor": "Vendor 40"}, {"kind": "ward", "name": "UBND Hòa Bình", "gateway": "192.168.1.1", "pointId": "hnth-branch-17", "ipAddress": "192.168.1.93", "modelVendor": "Vendor 41"}, {"kind": "ward", "name": "UBND Hồng An", "gateway": "192.168.1.1", "pointId": "hnth-branch-6", "ipAddress": "192.168.1.92", "modelVendor": "Vendor 42"}, {"kind": "ward", "name": "UBND Hồng Bàng", "gateway": "192.168.1.1", "pointId": "hnth-branch-15", "ipAddress": "192.168.1.91", "modelVendor": "Vendor 43"}, {"kind": "ward", "name": "UBND Hồng Châu", "gateway": "192.168.1.1", "pointId": "hnth-branch-49", "ipAddress": "192.168.1.90", "modelVendor": "Vendor 44"}, {"kind": "ward", "name": "UBND Hợp Tiến", "gateway": "192.168.1.1", "pointId": "hnth-branch-104", "ipAddress": "192.168.1.89", "modelVendor": "Vendor 45"}, {"kind": "ward", "name": "UBND Hùng Thắng", "gateway": "192.168.1.1", "pointId": "hnth-branch-71", "ipAddress": "", "modelVendor": "Vendor 46"}, {"kind": "ward", "name": "UBND Hưng Đạo", "gateway": "192.168.1.1", "pointId": "hnth-branch-16", "ipAddress": "192.168.1.87", "modelVendor": "Vendor 47"}, {"kind": "ward", "name": "UBND Kẻ Sặt", "gateway": "192.168.1.1", "pointId": "hnth-branch-60", "ipAddress": "192.168.1.86", "modelVendor": "Vendor 48"}, {"kind": "ward", "name": "UBND Khúc Thừa Dụ", "gateway": "192.168.1.1", "pointId": "hnth-branch-48", "ipAddress": "192.168.1.85", "modelVendor": "Vendor 49"}, {"kind": "ward", "name": "UBND Kiến An", "gateway": "192.168.1.1", "pointId": "hnth-branch-10", "ipAddress": "192.168.1.84", "modelVendor": "Vendor 50"}, {"kind": "ward", "name": "UBND Kiến Hải", "gateway": "192.168.1.1", "pointId": "hnth-branch-72", "ipAddress": "192.168.1.83", "modelVendor": "Vendor 51"}, {"kind": "ward", "name": "UBND Kiến Hưng", "gateway": "192.168.1.1", "pointId": "hnth-branch-74", "ipAddress": "192.168.1.82", "modelVendor": "Vendor 52"}, {"kind": "ward", "name": "UBND Kiến Minh", "gateway": "192.168.1.1", "pointId": "hnth-branch-9", "ipAddress": "192.168.1.81", "modelVendor": "Vendor 53"}, {"kind": "ward", "name": "UBND Kiến Thụy", "gateway": "192.168.1.1", "pointId": "hnth-branch-8", "ipAddress": "192.168.1.80", "modelVendor": "Vendor 54"}, {"kind": "ward", "name": "UBND Kim Thành", "gateway": "192.168.1.1", "pointId": "hnth-branch-103", "ipAddress": "192.168.1.79", "modelVendor": "Vendor 55"}, {"kind": "ward", "name": "UBND Kinh Môn", "gateway": "192.168.1.1", "pointId": "hnth-branch-52", "ipAddress": "192.168.1.78", "modelVendor": "Vendor 56"}, {"kind": "ward", "name": "UBND Lạc Phượng", "gateway": "192.168.1.1", "pointId": "hnth-branch-44", "ipAddress": "192.168.1.77", "modelVendor": "Vendor 57"}, {"kind": "ward", "name": "UBND Lai Khê", "gateway": "192.168.1.1", "pointId": "hnth-branch-95", "ipAddress": "192.168.1.76", "modelVendor": "Vendor 58"}, {"kind": "ward", "name": "UBND Lê Chân", "gateway": "192.168.1.1", "pointId": "hnth-branch-12", "ipAddress": "192.168.1.75", "modelVendor": "Vendor 59"}, {"kind": "ward", "name": "UBND Lê Đại Hành", "gateway": "192.168.1.1", "pointId": "hnth-branch-54", "ipAddress": "192.168.1.74", "modelVendor": "Vendor 60"}, {"kind": "ward", "name": "UBND Lê Ích Mộc", "gateway": "192.168.1.1", "pointId": "hnth-branch-5", "ipAddress": "192.168.1.73", "modelVendor": "Vendor 61"}, {"kind": "ward", "name": "UBND Lê Thanh Nghị", "gateway": "192.168.1.1", "pointId": "hnth-branch-114", "ipAddress": "192.168.1.72", "modelVendor": "Vendor 62"}, {"kind": "ward", "name": "UBND Lưu Kiếm", "gateway": "192.168.1.1", "pointId": "hnth-branch-19", "ipAddress": "192.168.1.71", "modelVendor": "Vendor 63"}, {"kind": "ward", "name": "UBND Mao Điền", "gateway": "192.168.1.1", "pointId": "hnth-branch-61", "ipAddress": "192.168.1.70", "modelVendor": "Vendor 64"}, {"kind": "ward", "name": "UBND Nam An Phụ", "gateway": "192.168.1.1", "pointId": "hnth-branch-90", "ipAddress": "192.168.1.69", "modelVendor": "Vendor 65"}, {"kind": "ward", "name": "UBND Nam Đồ Sơn", "gateway": "192.168.1.1", "pointId": "hnth-branch-73", "ipAddress": "192.168.1.68", "modelVendor": "Vendor 66"}, {"kind": "ward", "name": "UBND Nam Đồng", "gateway": "192.168.1.1", "pointId": "hnth-branch-67", "ipAddress": "192.168.1.67", "modelVendor": "Vendor 67"}, {"kind": "ward", "name": "UBND Nam Sách", "gateway": "192.168.1.1", "pointId": "hnth-branch-76", "ipAddress": "192.168.1.66", "modelVendor": "Vendor 68"}, {"kind": "ward", "name": "UBND Nam Thanh Miện", "gateway": "192.168.1.1", "pointId": "hnth-branch-50", "ipAddress": "192.168.1.65", "modelVendor": "Vendor 69"}, {"kind": "ward", "name": "UBND Nam Triệu", "gateway": "192.168.1.1", "pointId": "hnth-branch-81", "ipAddress": "192.168.1.64", "modelVendor": "Vendor 70"}, {"kind": "ward", "name": "UBND Nghi Dương", "gateway": "192.168.1.1", "pointId": "hnth-branch-39", "ipAddress": "192.168.1.63", "modelVendor": "Vendor 71"}, {"kind": "ward", "name": "UBND Ngô Quyền", "gateway": "192.168.1.1", "pointId": "hnth-branch-84", "ipAddress": "192.168.1.62", "modelVendor": "Vendor 72"}, {"kind": "ward", "name": "UBND Nguyễn Bỉnh Khiêm", "gateway": "192.168.1.1", "pointId": "hnth-branch-29", "ipAddress": "192.168.1.61", "modelVendor": "Vendor 73"}, {"kind": "ward", "name": "UBND Nguyễn Đại Năng", "gateway": "192.168.1.1", "pointId": "hnth-branch-53", "ipAddress": "192.168.1.60", "modelVendor": "Vendor 74"}, {"kind": "ward", "name": "UBND Nguyên Giáp", "gateway": "192.168.1.1", "pointId": "hnth-branch-43", "ipAddress": "192.168.1.59", "modelVendor": "Vendor 75"}, {"kind": "ward", "name": "UBND Nguyễn Lương Bằng", "gateway": "192.168.1.1", "pointId": "hnth-branch-100", "ipAddress": "192.168.1.58", "modelVendor": "Vendor 76"}, {"kind": "ward", "name": "UBND Nguyễn Trãi", "gateway": "192.168.1.1", "pointId": "hnth-branch-57", "ipAddress": "192.168.1.57", "modelVendor": "Vendor 77"}, {"kind": "ward", "name": "UBND Nhị Chiểu", "gateway": "192.168.1.1", "pointId": "hnth-branch-109", "ipAddress": "192.168.1.56", "modelVendor": "Vendor 78"}, {"kind": "ward", "name": "UBND Ninh Giang", "gateway": "192.168.1.1", "pointId": "hnth-branch-45", "ipAddress": "192.168.1.55", "modelVendor": "Vendor 79"}, {"kind": "ward", "name": "UBND Phạm Sư Mạnh", "gateway": "192.168.1.1", "pointId": "hnth-branch-55", "ipAddress": "192.168.1.54", "modelVendor": "Vendor 80"}, {"kind": "ward", "name": "UBND Phù Liễn", "gateway": "192.168.1.1", "pointId": "hnth-branch-3", "ipAddress": "192.168.1.53", "modelVendor": "Vendor 81"}, {"kind": "ward", "name": "UBND Phú Thái", "gateway": "192.168.1.1", "pointId": "hnth-branch-111", "ipAddress": "192.168.1.52", "modelVendor": "Vendor 82"}, {"kind": "ward", "name": "UBND Quyết Thắng", "gateway": "192.168.1.1", "pointId": "hnth-branch-36", "ipAddress": "192.168.1.51", "modelVendor": "Vendor 83"}, {"kind": "ward", "name": "UBND Tân An", "gateway": "192.168.1.1", "pointId": "hnth-branch-47", "ipAddress": "192.168.1.50", "modelVendor": "Vendor 84"}, {"kind": "ward", "name": "UBND Tân Hưng", "gateway": "192.168.1.1", "pointId": "hnth-branch-77", "ipAddress": "192.168.1.49", "modelVendor": "Vendor 85"}, {"kind": "ward", "name": "UBND Tân Kỳ", "gateway": "192.168.1.1", "pointId": "hnth-branch-99", "ipAddress": "192.168.1.48", "modelVendor": "Vendor 86"}, {"kind": "ward", "name": "UBND Tân Minh", "gateway": "192.168.1.1", "pointId": "hnth-branch-26", "ipAddress": "192.168.1.47", "modelVendor": "Vendor 87"}, {"kind": "ward", "name": "UBND Thạch Khôi", "gateway": "192.168.1.1", "pointId": "hnth-branch-112", "ipAddress": "192.168.1.46", "modelVendor": "Vendor 88"}, {"kind": "ward", "name": "UBND Thái Tân", "gateway": "192.168.1.1", "pointId": "hnth-branch-65", "ipAddress": "192.168.1.45", "modelVendor": "Vendor 89"}, {"kind": "ward", "name": "UBND Thành Đông", "gateway": "192.168.1.1", "pointId": "hnth-branch-113", "ipAddress": "192.168.1.44", "modelVendor": "Vendor 90"}, {"kind": "ward", "name": "UBND Thanh Hà", "gateway": "192.168.1.1", "pointId": "hnth-branch-88", "ipAddress": "192.168.1.43", "modelVendor": "Vendor 91"}, {"kind": "ward", "name": "UBND Thanh Miện", "gateway": "192.168.1.1", "pointId": "hnth-branch-102", "ipAddress": "192.168.1.42", "modelVendor": "Vendor 92"}, {"kind": "ward", "name": "UBND Thiên Hương", "gateway": "192.168.1.1", "pointId": "hnth-branch-7", "ipAddress": "192.168.1.41", "modelVendor": "Vendor 93"}, {"kind": "ward", "name": "UBND Thủy Nguyên", "gateway": "192.168.1.1", "pointId": "hnth-branch-82", "ipAddress": "192.168.1.40", "modelVendor": "Vendor 94"}, {"kind": "ward", "name": "UBND Thượng Hồng", "gateway": "192.168.1.1", "pointId": "hnth-branch-51", "ipAddress": "192.168.1.39", "modelVendor": "Vendor 95"}, {"kind": "ward", "name": "UBND Tiên Lãng", "gateway": "192.168.1.1", "pointId": "hnth-branch-24", "ipAddress": "192.168.1.38", "modelVendor": "Vendor 96"}, {"kind": "ward", "name": "UBND Tiên Minh", "gateway": "192.168.1.1", "pointId": "hnth-branch-25", "ipAddress": "192.168.1.37", "modelVendor": "Vendor 97"}, {"kind": "ward", "name": "UBND Trần Hưng Đạo", "gateway": "192.168.1.1", "pointId": "hnth-branch-56", "ipAddress": "192.168.1.36", "modelVendor": "Vendor 98"}, {"kind": "ward", "name": "UBND Trần Liễu", "gateway": "192.168.1.1", "pointId": "hnth-branch-87", "ipAddress": "192.168.1.15", "modelVendor": "Vendor 99"}, {"kind": "ward", "name": "UBND Trần Nhân Tông", "gateway": "192.168.1.1", "pointId": "hnth-branch-58", "ipAddress": "192.168.1.14", "modelVendor": "Vendor 100"}, {"kind": "ward", "name": "UBND Trần Phú", "gateway": "192.168.1.1", "pointId": "hnth-branch-105", "ipAddress": "192.168.1.13", "modelVendor": "Vendor 101"}, {"kind": "ward", "name": "UBND Trường Tân", "gateway": "192.168.1.1", "pointId": "hnth-branch-101", "ipAddress": "192.168.1.12", "modelVendor": "Vendor 102"}, {"kind": "ward", "name": "UBND Tuệ Tĩnh", "gateway": "192.168.1.1", "pointId": "hnth-branch-79", "ipAddress": "192.168.1.11", "modelVendor": "Vendor 103"}, {"kind": "ward", "name": "UBND Tứ Kỳ", "gateway": "192.168.1.1", "pointId": "hnth-branch-98", "ipAddress": "192.168.1.10", "modelVendor": "Vendor 104"}, {"kind": "ward", "name": "UBND Tứ Minh", "gateway": "192.168.1.1", "pointId": "hnth-branch-66", "ipAddress": "192.168.1.9", "modelVendor": "Vendor 105"}, {"kind": "ward", "name": "UBND Việt Hòa", "gateway": "192.168.1.1", "pointId": "hnth-branch-80", "ipAddress": "192.168.1.8", "modelVendor": "Vendor 106"}, {"kind": "ward", "name": "UBND Việt Khê", "gateway": "192.168.1.1", "pointId": "hnth-branch-4", "ipAddress": "192.168.1.7", "modelVendor": "Vendor 107"}, {"kind": "ward", "name": "UBND Vĩnh Am", "gateway": "192.168.1.1", "pointId": "hnth-branch-30", "ipAddress": "192.168.1.6", "modelVendor": "Vendor 108"}, {"kind": "ward", "name": "UBND Vĩnh Bảo", "gateway": "192.168.1.1", "pointId": "hnth-branch-21", "ipAddress": "192.168.1.5", "modelVendor": "Vendor 109"}, {"kind": "ward", "name": "UBND Vĩnh Hải", "gateway": "192.168.1.1", "pointId": "hnth-branch-28", "ipAddress": "192.168.1.4", "modelVendor": "Vendor 110"}, {"kind": "ward", "name": "UBND Vĩnh Hòa", "gateway": "192.168.1.1", "pointId": "hnth-branch-23", "ipAddress": "192.168.1.3", "modelVendor": "Vendor 111"}, {"kind": "ward", "name": "UBND Vĩnh Lại", "gateway": "192.168.1.1", "pointId": "hnth-branch-46", "ipAddress": "192.168.1.2", "modelVendor": "Vendor 112"}, {"kind": "ward", "name": "UBND Vĩnh Thịnh", "gateway": "192.168.1.1", "pointId": "hnth-branch-22", "ipAddress": "192.168.1.135", "modelVendor": "Vendor 113"}, {"kind": "ward", "name": "UBND Vĩnh Thuận", "gateway": "192.168.1.1", "pointId": "hnth-branch-37", "ipAddress": "192.168.1.0", "modelVendor": "Vendor 114"}, {"kind": "ward", "name": "UBND Yết Kiêu", "gateway": "192.168.1.1", "pointId": "hnth-branch-40", "ipAddress": "192.168.1.16", "modelVendor": "Vendor 115"}, {"kind": "extra", "name": "Sở Khoa học và Công nghệ", "gateway": "192.168.1.1", "pointId": "hnth-extra-so-khoa-hoc-va-cong-nghe", "ipAddress": "192.168.1.170", "modelVendor": "Vendor 116"}, {"kind": "extra", "name": "Sở Văn hóa và Du lịch", "gateway": "192.168.1.1", "pointId": "hnth-extra-so-van-hoa-va-du-lich", "ipAddress": "192.168.1.171", "modelVendor": "Vendor 117"}, {"kind": "extra", "name": "Sở Nông nghiệp và Môi trường", "gateway": "192.168.1.1", "pointId": "hnth-extra-so-nong-nghiep-va-moi-truong", "ipAddress": "192.168.1.172", "modelVendor": "Vendor 118"}, {"kind": "extra", "name": "Sở Tài chính", "gateway": "192.168.1.1", "pointId": "hnth-extra-so-tai-chinh", "ipAddress": "192.168.1.173", "modelVendor": "Vendor 119"}, {"kind": "extra", "name": "Sở Công Thương", "gateway": "192.168.1.1", "pointId": "hnth-extra-so-cong-thuong", "ipAddress": "192.168.1.174", "modelVendor": "Vendor 120"}, {"kind": "extra", "name": "Sở Ngoại Vụ", "gateway": "192.168.1.1", "pointId": "hnth-extra-so-ngoai-vu", "ipAddress": "192.168.1.175", "modelVendor": "Vendor 121"}, {"kind": "extra", "name": "Sở Nội Vụ", "gateway": "192.168.1.1", "pointId": "hnth-extra-so-noi-vu", "ipAddress": "192.168.1.176", "modelVendor": "Vendor 122"}, {"kind": "extra", "name": "Sở Y Tế", "gateway": "192.168.1.1", "pointId": "hnth-extra-so-y-te", "ipAddress": "192.168.1.177", "modelVendor": "Vendor 123"}, {"kind": "extra", "name": "Sở Giáo Dục và Đào Tạo", "gateway": "192.168.1.1", "pointId": "hnth-extra-so-giao-duc-va-dao-tao", "ipAddress": "192.168.1.178", "modelVendor": "Vendor 124"}, {"kind": "extra", "name": "Ban Quản lý các KKT", "gateway": "192.168.1.1", "pointId": "hnth-extra-ban-quan-ly-cac-kkt", "ipAddress": "192.168.1.179", "modelVendor": "Vendor 125"}, {"kind": "extra", "name": "Vườn Quốc Gia Cát Bà", "gateway": "192.168.1.1", "pointId": "hnth-extra-vuon-quoc-gia-cat-ba", "ipAddress": "192.168.1.180", "modelVendor": "Vendor 126"}]	2026-10-22 04:45:01.567981+07
\.


--
-- Data for Name: hnth_rosters; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.hnth_rosters (id, name, created_by, created_at, updated_at, point_ids) FROM stdin;
6a125e42-30cb-4092-8069-091e7788bf61	UBND - Xã/Phường/Đặc khu	529aaa52-59df-48eb-94bf-8a96a7e1b1b3	2026-10-22 03:08:10.06163+07	2026-10-22 04:45:01.567981+07	["hnth-hub", "hnth-branch-110", "hnth-branch-13", "hnth-branch-20", "hnth-branch-2", "hnth-branch-38", "hnth-branch-35", "hnth-branch-33", "hnth-branch-31", "hnth-branch-89", "hnth-branch-34", "hnth-branch-93", "hnth-branch-32", "hnth-branch-18", "hnth-branch-1", "hnth-branch-108", "hnth-branch-42", "hnth-branch-62", "hnth-branch-69", "hnth-branch-59", "hnth-branch-64", "hnth-branch-27", "hnth-branch-107", "hnth-branch-97", "hnth-branch-106", "hnth-branch-75", "hnth-branch-92", "hnth-branch-70", "hnth-branch-83", "hnth-branch-63", "hnth-branch-68", "hnth-branch-78", "hnth-branch-14", "hnth-branch-96", "hnth-branch-86", "hnth-branch-94", "hnth-branch-91", "hnth-branch-11", "hnth-branch-85", "hnth-branch-41", "hnth-branch-17", "hnth-branch-6", "hnth-branch-15", "hnth-branch-49", "hnth-branch-104", "hnth-branch-71", "hnth-branch-16", "hnth-branch-60", "hnth-branch-48", "hnth-branch-10", "hnth-branch-72", "hnth-branch-74", "hnth-branch-9", "hnth-branch-8", "hnth-branch-103", "hnth-branch-52", "hnth-branch-44", "hnth-branch-95", "hnth-branch-12", "hnth-branch-54", "hnth-branch-5", "hnth-branch-114", "hnth-branch-19", "hnth-branch-61", "hnth-branch-90", "hnth-branch-73", "hnth-branch-67", "hnth-branch-76", "hnth-branch-50", "hnth-branch-81", "hnth-branch-39", "hnth-branch-84", "hnth-branch-29", "hnth-branch-53", "hnth-branch-43", "hnth-branch-100", "hnth-branch-57", "hnth-branch-109", "hnth-branch-45", "hnth-branch-55", "hnth-branch-3", "hnth-branch-111", "hnth-branch-36", "hnth-branch-47", "hnth-branch-77", "hnth-branch-99", "hnth-branch-26", "hnth-branch-112", "hnth-branch-65", "hnth-branch-113", "hnth-branch-88", "hnth-branch-102", "hnth-branch-7", "hnth-branch-82", "hnth-branch-51", "hnth-branch-24", "hnth-branch-25", "hnth-branch-56", "hnth-branch-87", "hnth-branch-58", "hnth-branch-105", "hnth-branch-101", "hnth-branch-79", "hnth-branch-98", "hnth-branch-66", "hnth-branch-80", "hnth-branch-4", "hnth-branch-30", "hnth-branch-21", "hnth-branch-28", "hnth-branch-23", "hnth-branch-46", "hnth-branch-22", "hnth-branch-37", "hnth-branch-40"]
\.


--
-- Data for Name: monitor_logs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.monitor_logs (id, agent_id, endpoint_id, ip_address, status, latency_ms, packet_loss_pct, jitter_ms, checked_at, received_at) FROM stdin;
1	agent-demo	hnth-branch-1	192.168.1.160	online	48	0	6.67	2026-10-21 00:34:13.396+07	2026-10-21 00:34:13.402385+07
2	agent-demo	hnth-branch-10	192.168.1.84	online	256	75	0	2026-10-21 00:34:16.88+07	2026-10-21 00:34:16.887129+07
3	agent-demo	hnth-branch-100	192.168.1.58	online	239	75	0	2026-10-21 00:34:20.376+07	2026-10-21 00:34:20.380229+07
4	agent-demo	hnth-branch-101	192.168.1.12	online	241	75	0	2026-10-21 00:34:23.88+07	2026-10-21 00:34:23.884707+07
5	agent-demo	hnth-branch-102	192.168.1.42	online	225	75	0	2026-10-21 00:34:27.368+07	2026-10-21 00:34:27.371707+07
6	agent-demo	hnth-branch-103	192.168.1.79	online	226	75	0	2026-10-21 00:34:30.872+07	2026-10-21 00:34:30.87603+07
7	agent-demo	hnth-branch-104	192.168.1.89	online	239	75	0	2026-10-21 00:34:34.368+07	2026-10-21 00:34:34.375158+07
8	agent-demo	hnth-branch-105	192.168.1.13	online	224	75	0	2026-10-21 00:34:37.871+07	2026-10-21 00:34:37.87475+07
9	agent-demo	hnth-branch-106	192.168.1.109	online	241	75	0	2026-10-21 00:34:41.369+07	2026-10-21 00:34:41.378035+07
10	agent-demo	hnth-branch-107	192.168.1.111	online	256	75	0	2026-10-21 00:34:44.876+07	2026-10-21 00:34:44.886256+07
11	agent-demo	hnth-branch-108	192.168.1.118	online	257	75	0	2026-10-21 00:34:48.373+07	2026-10-21 00:34:48.383253+07
12	agent-demo	hnth-branch-109	192.168.1.56	online	244	75	0	2026-10-21 00:34:51.873+07	2026-10-21 00:34:51.877488+07
13	agent-demo	hnth-branch-1	192.168.1.160	online	50	0	4.67	2026-10-21 00:34:49.466+07	2026-10-21 00:34:52.383792+07
14	agent-demo	hnth-branch-10	192.168.1.84	online	758	75	0	2026-10-21 00:34:52.378+07	2026-10-21 00:34:52.385987+07
15	agent-demo	hnth-branch-100	192.168.1.58	online	731	75	0	2026-10-21 00:34:56.369+07	2026-10-21 00:34:56.374566+07
16	agent-demo	hnth-branch-101	192.168.1.12	online	721	75	0	2026-10-21 00:34:56.37+07	2026-10-21 00:34:56.377121+07
17	agent-demo	hnth-branch-102	192.168.1.42	online	724	75	0	2026-10-21 00:35:00.375+07	2026-10-21 00:35:00.379988+07
18	agent-demo	hnth-branch-103	192.168.1.79	online	733	75	0	2026-10-21 00:35:00.375+07	2026-10-21 00:35:00.382766+07
19	agent-demo	hnth-branch-104	192.168.1.89	online	758	75	0	2026-10-21 00:35:04.374+07	2026-10-21 00:35:04.379059+07
20	agent-demo	hnth-branch-105	192.168.1.13	online	746	75	0	2026-10-21 00:35:04.374+07	2026-10-21 00:35:04.382126+07
21	agent-demo	hnth-branch-106	192.168.1.109	online	719	75	0	2026-10-21 00:35:08.371+07	2026-10-21 00:35:08.377064+07
22	agent-demo	hnth-branch-107	192.168.1.111	online	728	75	0	2026-10-21 00:35:08.371+07	2026-10-21 00:35:08.380635+07
23	agent-demo	hnth-branch-108	192.168.1.118	online	722	75	0	2026-10-21 00:35:12.377+07	2026-10-21 00:35:12.381014+07
24	agent-demo	hnth-branch-109	192.168.1.56	online	730	75	0	2026-10-21 00:35:12.377+07	2026-10-21 00:35:12.383026+07
25	agent-demo	hnth-branch-11	192.168.1.96	online	247	75	0	2026-10-21 00:35:15.872+07	2026-10-21 00:35:15.876355+07
26	agent-demo	hnth-branch-110	192.168.1.159	online	256	75	0	2026-10-21 00:35:15.872+07	2026-10-21 00:35:15.877868+07
27	agent-demo	hnth-branch-111	192.168.1.52	online	60	0	19	2026-10-21 00:35:16.881+07	2026-10-21 00:35:19.375397+07
28	agent-demo	hnth-branch-112	192.168.1.46	online	255	75	0	2026-10-21 00:35:19.371+07	2026-10-21 00:35:19.377398+07
29	agent-demo	hnth-branch-113	192.168.1.44	online	231	75	0	2026-10-21 00:35:22.867+07	2026-10-21 00:35:22.871132+07
30	agent-demo	hnth-branch-114	192.168.1.72	online	240	75	0	2026-10-21 00:35:22.867+07	2026-10-21 00:35:22.872933+07
31	agent-demo	hnth-branch-12	192.168.1.75	online	233	75	0	2026-10-21 00:35:26.375+07	2026-10-21 00:35:26.37924+07
32	agent-demo	hnth-branch-13	192.168.1.158	online	243	75	0	2026-10-21 00:35:26.375+07	2026-10-21 00:35:26.381491+07
33	agent-demo	hnth-branch-14	192.168.1.101	online	241	75	0	2026-10-21 00:35:29.884+07	2026-10-21 00:35:29.887915+07
34	agent-demo	hnth-branch-15	192.168.1.91	online	233	75	0	2026-10-21 00:35:29.883+07	2026-10-21 00:35:29.88929+07
35	agent-demo	hnth-branch-16	192.168.1.87	online	234	75	0	2026-10-21 00:35:33.373+07	2026-10-21 00:35:33.381489+07
36	agent-demo	hnth-branch-17	192.168.1.93	online	242	75	0	2026-10-21 00:35:33.374+07	2026-10-21 00:35:33.386364+07
37	agent-demo	hnth-branch-18	192.168.1.120	online	242	75	0	2026-10-21 00:35:36.869+07	2026-10-21 00:35:36.876252+07
38	agent-demo	hnth-branch-19	192.168.1.71	online	233	75	0	2026-10-21 00:35:36.869+07	2026-10-21 00:35:36.877785+07
39	agent-demo	hnth-branch-2	192.168.1.156	online	232	75	0	2026-10-21 00:35:40.377+07	2026-10-21 00:35:40.413196+07
40	agent-demo	hnth-branch-20	192.168.1.157	online	240	75	0	2026-10-21 00:35:40.377+07	2026-10-21 00:35:40.415274+07
41	agent-demo	hnth-branch-21	192.168.1.5	online	65	0	26	2026-10-21 00:35:41.44+07	2026-10-21 00:35:43.879396+07
42	agent-demo	hnth-branch-22	192.168.1.135	online	240	75	0	2026-10-21 00:35:43.875+07	2026-10-21 00:35:43.881458+07
43	agent-demo	hnth-branch-23	192.168.1.3	online	226	75	0	2026-10-21 00:35:47.374+07	2026-10-21 00:35:47.378089+07
44	agent-demo	hnth-branch-24	192.168.1.38	online	237	75	0	2026-10-21 00:35:47.374+07	2026-10-21 00:35:47.380527+07
45	agent-demo	hnth-branch-25	192.168.1.37	online	218	75	0	2026-10-21 00:35:50.872+07	2026-10-21 00:35:50.876081+07
46	agent-demo	hnth-branch-26	192.168.1.47	online	226	75	0	2026-10-21 00:35:50.872+07	2026-10-21 00:35:50.877357+07
47	agent-demo	hnth-branch-27	192.168.1.112	online	256	75	0	2026-10-21 00:35:54.371+07	2026-10-21 00:35:54.374219+07
48	agent-demo	hnth-branch-28	192.168.1.4	online	45	0	7	2026-10-21 00:35:51.848+07	2026-10-21 00:35:54.37555+07
49	agent-demo	hnth-branch-29	192.168.1.61	online	240	75	0	2026-10-21 00:35:57.881+07	2026-10-21 00:35:57.886922+07
50	agent-demo	hnth-branch-3	192.168.1.53	online	231	75	0	2026-10-21 00:35:57.881+07	2026-10-21 00:35:57.888392+07
51	agent-demo	hnth-branch-30	192.168.1.6	online	49	0	10	2026-10-21 00:35:58.854+07	2026-10-21 00:36:01.388083+07
52	agent-demo	hnth-branch-31	192.168.1.125	online	254	75	0	2026-10-21 00:36:01.381+07	2026-10-21 00:36:01.391055+07
53	agent-demo	hnth-branch-32	192.168.1.121	online	234	75	0	2026-10-21 00:36:04.88+07	2026-10-21 00:36:04.883474+07
54	agent-demo	hnth-branch-33	192.168.1.126	online	242	75	0	2026-10-21 00:36:04.88+07	2026-10-21 00:36:04.885014+07
55	agent-demo	hnth-branch-34	192.168.1.123	online	241	75	0	2026-10-21 00:36:08.378+07	2026-10-21 00:36:08.38303+07
56	agent-demo	hnth-branch-35	192.168.1.161	online	233	75	0	2026-10-21 00:36:08.378+07	2026-10-21 00:36:08.384402+07
57	agent-demo	hnth-branch-36	192.168.1.51	online	242	75	0	2026-10-21 00:36:11.869+07	2026-10-21 00:36:11.874684+07
58	agent-demo	hnth-branch-37	192.168.1.0	online	233	75	0	2026-10-21 00:36:11.869+07	2026-10-21 00:36:11.876241+07
59	agent-demo	hnth-branch-38	192.168.1.155	online	233	75	0	2026-10-21 00:36:15.377+07	2026-10-21 00:36:15.383188+07
60	agent-demo	hnth-branch-39	192.168.1.63	online	239	75	0	2026-10-21 00:36:15.377+07	2026-10-21 00:36:15.385828+07
61	agent-demo	hnth-branch-4	192.168.1.7	online	101	0	84.33	2026-10-21 00:36:16.559+07	2026-10-21 00:36:18.890001+07
62	agent-demo	hnth-branch-40	192.168.1.16	online	257	75	0	2026-10-21 00:36:18.884+07	2026-10-21 00:36:18.89292+07
63	agent-demo	hnth-branch-41	192.168.1.94	online	244	75	0	2026-10-21 00:36:22.373+07	2026-10-21 00:36:22.376962+07
64	agent-demo	hnth-branch-42	192.168.1.117	online	235	75	0	2026-10-21 00:36:22.373+07	2026-10-21 00:36:22.378696+07
65	agent-demo	hnth-branch-43	192.168.1.59	online	223	75	0	2026-10-21 00:36:25.88+07	2026-10-21 00:36:25.883866+07
66	agent-demo	hnth-branch-44	192.168.1.77	online	215	75	0	2026-10-21 00:36:25.88+07	2026-10-21 00:36:25.885103+07
67	agent-demo	hnth-branch-45	192.168.1.55	online	241	75	0	2026-10-21 00:36:29.367+07	2026-10-21 00:36:29.369891+07
68	agent-demo	hnth-branch-46	192.168.1.2	online	59	0	34.67	2026-10-21 00:36:26.904+07	2026-10-21 00:36:29.371287+07
69	agent-demo	hnth-branch-47	192.168.1.50	online	50	0	8.33	2026-10-21 00:36:30.345+07	2026-10-21 00:36:32.874709+07
70	agent-demo	hnth-branch-48	192.168.1.85	online	224	75	0	2026-10-21 00:36:32.871+07	2026-10-21 00:36:32.876182+07
71	agent-demo	hnth-branch-49	192.168.1.90	online	242	75	0	2026-10-21 00:36:36.371+07	2026-10-21 00:36:36.374837+07
72	agent-demo	hnth-branch-5	192.168.1.73	online	234	75	0	2026-10-21 00:36:36.371+07	2026-10-21 00:36:36.376433+07
73	agent-demo	hnth-branch-50	192.168.1.65	online	243	75	0	2026-10-21 00:36:39.878+07	2026-10-21 00:36:39.889249+07
74	agent-demo	hnth-branch-51	192.168.1.39	online	236	75	0	2026-10-21 00:36:39.879+07	2026-10-21 00:36:39.891308+07
75	agent-demo	hnth-branch-52	192.168.1.78	online	228	75	0	2026-10-21 00:36:43.371+07	2026-10-21 00:36:43.374337+07
76	agent-demo	hnth-branch-53	192.168.1.60	online	238	75	0	2026-10-21 00:36:43.371+07	2026-10-21 00:36:43.376323+07
77	agent-demo	hnth-branch-54	192.168.1.74	online	241	75	0	2026-10-21 00:36:46.873+07	2026-10-21 00:36:46.87787+07
78	agent-demo	hnth-branch-55	192.168.1.54	online	233	75	0	2026-10-21 00:36:46.873+07	2026-10-21 00:36:46.879366+07
79	agent-demo	hnth-branch-56	192.168.1.36	online	240	75	0	2026-10-21 00:36:50.371+07	2026-10-21 00:36:50.37441+07
80	agent-demo	hnth-branch-57	192.168.1.57	online	232	75	0	2026-10-21 00:36:50.371+07	2026-10-21 00:36:50.375641+07
81	agent-demo	hnth-branch-58	192.168.1.14	online	215	75	0	2026-10-21 00:36:53.878+07	2026-10-21 00:36:53.881856+07
82	agent-demo	hnth-branch-59	192.168.1.114	online	226	75	0	2026-10-21 00:36:53.879+07	2026-10-21 00:36:53.883288+07
83	agent-demo	hnth-branch-6	192.168.1.92	online	247	75	0	2026-10-21 00:36:57.373+07	2026-10-21 00:36:57.375827+07
84	agent-demo	hnth-branch-60	192.168.1.86	online	255	75	0	2026-10-21 00:36:57.373+07	2026-10-21 00:36:57.377092+07
85	agent-demo	hnth-branch-61	192.168.1.70	online	240	75	0	2026-10-21 00:37:00.87+07	2026-10-21 00:37:00.874279+07
86	agent-demo	hnth-branch-62	192.168.1.116	online	232	75	0	2026-10-21 00:37:00.869+07	2026-10-21 00:37:00.875663+07
87	agent-demo	hnth-branch-63	192.168.1.104	online	233	75	0	2026-10-21 00:37:04.378+07	2026-10-21 00:37:04.3811+07
88	agent-demo	hnth-branch-64	192.168.1.113	online	242	75	0	2026-10-21 00:37:04.378+07	2026-10-21 00:37:04.382374+07
89	agent-demo	hnth-branch-65	192.168.1.45	online	224	75	0	2026-10-21 00:37:07.881+07	2026-10-21 00:37:07.884213+07
90	agent-demo	hnth-branch-66	192.168.1.9	online	212	75	0	2026-10-21 00:37:07.881+07	2026-10-21 00:37:07.885606+07
91	agent-demo	hnth-branch-67	192.168.1.67	online	234	75	0	2026-10-21 00:37:11.379+07	2026-10-21 00:37:11.382363+07
92	agent-demo	hnth-branch-68	192.168.1.103	online	242	75	0	2026-10-21 00:37:11.379+07	2026-10-21 00:37:11.38393+07
93	agent-demo	hnth-branch-69	192.168.1.1	online	45	0	2.33	2026-10-21 00:37:12.337+07	2026-10-21 00:37:14.871603+07
94	agent-demo	hnth-branch-7	192.168.1.41	online	242	75	0	2026-10-21 00:37:14.868+07	2026-10-21 00:37:14.873409+07
95	agent-demo	hnth-branch-70	192.168.1.106	online	242	75	0	2026-10-21 00:37:18.376+07	2026-10-21 00:37:18.379216+07
96	agent-demo	hnth-branch-71	\N	unknown	\N	\N	\N	2026-10-21 00:37:14.886+07	2026-10-21 00:37:18.380755+07
97	agent-demo	hnth-branch-72	192.168.1.83	online	231	75	0	2026-10-21 00:37:21.867+07	2026-10-21 00:37:21.870693+07
98	agent-demo	hnth-branch-73	192.168.1.68	online	239	75	0	2026-10-21 00:37:21.868+07	2026-10-21 00:37:21.871931+07
99	agent-demo	hnth-branch-74	192.168.1.82	online	233	75	0	2026-10-21 00:37:25.381+07	2026-10-21 00:37:25.384224+07
100	agent-demo	hnth-branch-75	192.168.1.108	online	241	75	0	2026-10-21 00:37:25.381+07	2026-10-21 00:37:25.385554+07
101	agent-demo	hnth-branch-76	192.168.1.66	online	241	75	0	2026-10-21 00:37:28.873+07	2026-10-21 00:37:28.879522+07
102	agent-demo	hnth-branch-77	192.168.1.49	online	44	0	3	2026-10-21 00:37:26.368+07	2026-10-21 00:37:28.882893+07
103	agent-demo	hnth-branch-78	192.168.1.102	online	240	75	0	2026-10-21 00:37:32.377+07	2026-10-21 00:37:32.871953+07
104	agent-demo	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 00:37:32.868+07	2026-10-21 00:37:32.873399+07
105	agent-demo	hnth-branch-8	192.168.1.80	online	232	75	0	2026-10-21 00:37:36.368+07	2026-10-21 00:37:36.878277+07
106	agent-demo	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 00:37:36.875+07	2026-10-21 00:37:36.879794+07
107	agent-demo	hnth-branch-81	192.168.1.64	online	256	75	0	2026-10-21 00:37:40.374+07	2026-10-21 00:37:40.377528+07
108	agent-demo	hnth-branch-82	192.168.1.40	online	249	75	0	2026-10-21 00:37:40.374+07	2026-10-21 00:37:40.378797+07
109	agent-demo	hnth-branch-83	192.168.1.105	online	239	75	0	2026-10-21 00:37:43.879+07	2026-10-21 00:37:43.883711+07
110	agent-demo	hnth-branch-84	192.168.1.62	online	229	75	0	2026-10-21 00:37:43.879+07	2026-10-21 00:37:43.885409+07
111	agent-demo	hnth-branch-85	192.168.1.95	online	258	75	0	2026-10-21 00:37:47.372+07	2026-10-21 00:37:47.375763+07
112	agent-demo	hnth-branch-86	192.168.1.99	online	250	75	0	2026-10-21 00:37:47.372+07	2026-10-21 00:37:47.37714+07
113	agent-demo	hnth-branch-87	192.168.1.15	online	232	75	0	2026-10-21 00:37:50.881+07	2026-10-21 00:37:50.884513+07
114	agent-demo	hnth-branch-88	192.168.1.43	online	240	75	0	2026-10-21 00:37:50.881+07	2026-10-21 00:37:50.88599+07
115	agent-demo	hnth-branch-89	192.168.1.124	online	230	75	0	2026-10-21 00:37:54.367+07	2026-10-21 00:37:54.371324+07
116	agent-demo	hnth-branch-9	192.168.1.81	online	239	75	0	2026-10-21 00:37:54.367+07	2026-10-21 00:37:54.372473+07
117	agent-demo	hnth-branch-90	192.168.1.69	online	233	75	0	2026-10-21 00:37:57.876+07	2026-10-21 00:37:57.879982+07
118	agent-demo	hnth-branch-91	192.168.1.97	online	241	75	0	2026-10-21 00:37:57.876+07	2026-10-21 00:37:57.881337+07
119	agent-demo	hnth-branch-92	192.168.1.107	online	239	75	0	2026-10-21 00:38:01.379+07	2026-10-21 00:38:01.382999+07
120	agent-demo	hnth-branch-93	192.168.1.122	online	232	75	0	2026-10-21 00:38:01.379+07	2026-10-21 00:38:01.384407+07
121	agent-demo	hnth-branch-94	192.168.1.98	online	225	75	0	2026-10-21 00:38:04.869+07	2026-10-21 00:38:04.872899+07
122	agent-demo	hnth-branch-95	192.168.1.76	online	217	75	0	2026-10-21 00:38:04.869+07	2026-10-21 00:38:04.874136+07
123	agent-demo	hnth-branch-96	192.168.1.100	online	241	75	0	2026-10-21 00:38:08.372+07	2026-10-21 00:38:08.376007+07
124	agent-demo	hnth-branch-97	192.168.1.110	online	234	75	0	2026-10-21 00:38:08.372+07	2026-10-21 00:38:08.377495+07
125	agent-demo	hnth-branch-98	192.168.1.10	online	738	75	0	2026-10-21 00:38:12.374+07	2026-10-21 00:38:12.377897+07
126	agent-demo	hnth-branch-99	192.168.1.48	online	226	75	0	2026-10-21 00:38:11.866+07	2026-10-21 00:38:12.379496+07
127	agent-demo	hnth-hub	192.168.1.169	online	239	75	0	2026-10-21 00:38:15.879+07	2026-10-21 00:38:15.882309+07
128	agent-demo	hnth-hub	192.168.1.169	online	239	75	0	2026-10-21 00:41:39.881+07	2026-10-21 00:41:40.387199+07
129	agent-demo	hnth-branch-49	192.168.1.90	online	243	75	0	2026-10-21 00:43:28.876+07	2026-10-21 00:43:28.883808+07
130	agent-demo	hnth-branch-1	192.168.1.160	online	53	0	13	2026-10-21 00:43:26.795+07	2026-10-21 00:43:28.884515+07
131	agent-demo	hnth-branch-5	192.168.1.73	online	235	75	0	2026-10-21 00:43:28.876+07	2026-10-21 00:43:28.886022+07
132	agent-demo	hnth-branch-10	192.168.1.84	online	224	75	0	2026-10-21 00:43:28.877+07	2026-10-21 00:43:28.886852+07
133	agent-demo	hnth-branch-100	192.168.1.58	online	258	75	0	2026-10-21 00:43:32.368+07	2026-10-21 00:43:32.375108+07
134	agent-demo	hnth-branch-101	192.168.1.12	online	250	75	0	2026-10-21 00:43:32.368+07	2026-10-21 00:43:32.377018+07
135	agent-demo	hnth-branch-102	192.168.1.42	online	231	75	0	2026-10-21 00:43:35.871+07	2026-10-21 00:43:35.875432+07
136	agent-demo	hnth-branch-103	192.168.1.79	online	240	75	0	2026-10-21 00:43:35.871+07	2026-10-21 00:43:35.876896+07
137	agent-demo	hnth-branch-104	192.168.1.89	online	236	75	0	2026-10-21 00:43:39.374+07	2026-10-21 00:43:39.382655+07
138	agent-demo	hnth-branch-105	192.168.1.13	online	245	75	0	2026-10-21 00:43:39.374+07	2026-10-21 00:43:39.385293+07
139	agent-demo	hnth-branch-106	192.168.1.109	online	239	75	0	2026-10-21 00:43:42.878+07	2026-10-21 00:43:42.89079+07
140	agent-demo	hnth-branch-107	192.168.1.111	online	231	75	0	2026-10-21 00:43:42.878+07	2026-10-21 00:43:42.892448+07
141	agent-demo	hnth-branch-108	192.168.1.118	online	241	75	0	2026-10-21 00:43:46.377+07	2026-10-21 00:43:46.382721+07
142	agent-demo	hnth-branch-109	192.168.1.56	online	232	75	0	2026-10-21 00:43:46.377+07	2026-10-21 00:43:46.385332+07
143	agent-demo	hnth-branch-11	192.168.1.96	online	239	75	0	2026-10-21 00:43:49.866+07	2026-10-21 00:43:49.870939+07
144	agent-demo	hnth-branch-110	192.168.1.159	online	231	75	0	2026-10-21 00:43:49.866+07	2026-10-21 00:43:49.872948+07
145	agent-demo	hnth-branch-111	192.168.1.52	online	47	0	3	2026-10-21 00:43:50.829+07	2026-10-21 00:43:53.379463+07
146	agent-demo	hnth-branch-112	192.168.1.46	online	240	75	0	2026-10-21 00:43:53.376+07	2026-10-21 00:43:53.380577+07
147	agent-demo	hnth-branch-113	192.168.1.44	online	258	75	0	2026-10-21 00:43:56.879+07	2026-10-21 00:43:56.883496+07
148	agent-demo	hnth-branch-114	192.168.1.72	online	249	75	0	2026-10-21 00:43:56.879+07	2026-10-21 00:43:56.885982+07
149	agent-demo	hnth-branch-12	192.168.1.75	online	239	75	0	2026-10-21 00:44:00.369+07	2026-10-21 00:44:00.37307+07
150	agent-demo	hnth-branch-13	192.168.1.158	online	231	75	0	2026-10-21 00:44:00.369+07	2026-10-21 00:44:00.374377+07
151	agent-demo	hnth-branch-14	192.168.1.101	online	240	75	0	2026-10-21 00:44:03.878+07	2026-10-21 00:44:03.881633+07
152	agent-demo	hnth-branch-15	192.168.1.91	online	233	75	0	2026-10-21 00:44:03.878+07	2026-10-21 00:44:03.883637+07
165	agent-demo	hnth-branch-27	192.168.1.112	online	242	75	0	2026-10-21 00:44:28.37+07	2026-10-21 00:44:28.374231+07
166	agent-demo	hnth-branch-28	192.168.1.4	online	52	0	18.33	2026-10-21 00:44:25.877+07	2026-10-21 00:44:28.375448+07
173	agent-demo	hnth-branch-34	192.168.1.123	online	231	75	0	2026-10-21 00:44:42.38+07	2026-10-21 00:44:42.386277+07
174	agent-demo	hnth-branch-35	192.168.1.161	online	241	75	0	2026-10-21 00:44:42.38+07	2026-10-21 00:44:42.387691+07
175	agent-demo	hnth-branch-36	192.168.1.51	online	242	75	0	2026-10-21 00:44:45.886+07	2026-10-21 00:44:45.894853+07
176	agent-demo	hnth-branch-37	192.168.1.0	online	233	75	0	2026-10-21 00:44:45.886+07	2026-10-21 00:44:45.898198+07
177	agent-demo	hnth-branch-38	192.168.1.155	online	240	75	0	2026-10-21 00:44:49.37+07	2026-10-21 00:44:49.373896+07
178	agent-demo	hnth-branch-39	192.168.1.63	online	232	75	0	2026-10-21 00:44:49.37+07	2026-10-21 00:44:49.375368+07
181	agent-demo	hnth-branch-41	192.168.1.94	online	231	75	0	2026-10-21 00:44:56.37+07	2026-10-21 00:44:56.374123+07
182	agent-demo	hnth-branch-42	192.168.1.117	online	240	75	0	2026-10-21 00:44:56.37+07	2026-10-21 00:44:56.375573+07
183	agent-demo	hnth-branch-43	192.168.1.59	online	240	75	0	2026-10-21 00:44:59.874+07	2026-10-21 00:44:59.880311+07
184	agent-demo	hnth-branch-44	192.168.1.77	online	232	75	0	2026-10-21 00:44:59.875+07	2026-10-21 00:44:59.883045+07
187	agent-demo	hnth-branch-47	192.168.1.50	online	59	0	23.33	2026-10-21 00:45:04.401+07	2026-10-21 00:45:06.878094+07
188	agent-demo	hnth-branch-48	192.168.1.85	online	226	75	0	2026-10-21 00:45:06.874+07	2026-10-21 00:45:06.879886+07
189	agent-demo	hnth-branch-49	192.168.1.90	online	240	75	0	2026-10-21 00:45:10.379+07	2026-10-21 00:45:10.385946+07
190	agent-demo	hnth-branch-5	192.168.1.73	online	233	75	0	2026-10-21 00:45:10.379+07	2026-10-21 00:45:10.389915+07
191	agent-demo	hnth-branch-50	192.168.1.65	online	238	75	0	2026-10-21 00:45:13.884+07	2026-10-21 00:45:13.891841+07
192	agent-demo	hnth-branch-51	192.168.1.39	online	229	75	0	2026-10-21 00:45:13.885+07	2026-10-21 00:45:13.895337+07
193	agent-demo	hnth-branch-52	192.168.1.78	online	222	75	0	2026-10-21 00:45:17.369+07	2026-10-21 00:45:17.373125+07
194	agent-demo	hnth-branch-53	192.168.1.60	online	231	75	0	2026-10-21 00:45:17.369+07	2026-10-21 00:45:17.374537+07
201	agent-demo	hnth-branch-6	192.168.1.92	online	257	75	0	2026-10-21 00:45:31.38+07	2026-10-21 00:45:31.387402+07
202	agent-demo	hnth-branch-60	192.168.1.86	online	249	75	0	2026-10-21 00:45:31.381+07	2026-10-21 00:45:31.390868+07
203	agent-demo	hnth-branch-61	192.168.1.70	online	231	75	0	2026-10-21 00:45:34.876+07	2026-10-21 00:45:34.884849+07
204	agent-demo	hnth-branch-62	192.168.1.116	online	240	75	0	2026-10-21 00:45:34.875+07	2026-10-21 00:45:34.888825+07
1251	agent-demo	hnth-branch-91	192.168.1.97	offline	233	75	0	2026-10-21 14:30:49.871+07	2026-10-21 14:30:49.880312+07
1252	agent-demo	hnth-branch-11	192.168.1.96	offline	237	75	0	2026-10-21 14:30:49.87+07	2026-10-21 14:30:49.89161+07
1255	agent-demo	hnth-branch-17	192.168.1.93	offline	231	75	0	2026-10-21 14:30:56.878+07	2026-10-21 14:30:56.881656+07
1256	agent-demo	hnth-branch-6	192.168.1.92	offline	235	75	0	2026-10-21 14:30:56.878+07	2026-10-21 14:30:56.883115+07
1261	agent-demo	hnth-branch-60	192.168.1.86	offline	232	75	0	2026-10-21 14:31:07.386+07	2026-10-21 14:31:07.395974+07
1262	agent-demo	hnth-branch-48	192.168.1.85	offline	237	75	0	2026-10-21 14:31:07.385+07	2026-10-21 14:31:07.39864+07
1263	agent-demo	hnth-branch-10	192.168.1.84	offline	237	75	0	2026-10-21 14:31:10.879+07	2026-10-21 14:31:10.883634+07
1264	agent-demo	hnth-branch-72	192.168.1.83	offline	240	75	0	2026-10-21 14:31:10.879+07	2026-10-21 14:31:10.885378+07
1267	agent-demo	hnth-branch-8	192.168.1.80	offline	252	75	0	2026-10-21 14:31:17.884+07	2026-10-21 14:31:17.891565+07
1268	agent-demo	hnth-branch-103	192.168.1.79	offline	247	75	0	2026-10-21 14:31:17.884+07	2026-10-21 14:31:17.894186+07
1269	agent-demo	hnth-branch-52	192.168.1.78	offline	204	75	0	2026-10-21 14:31:21.374+07	2026-10-21 14:31:21.381213+07
1270	agent-demo	hnth-branch-44	192.168.1.77	offline	234	75	0	2026-10-21 14:31:21.374+07	2026-10-21 14:31:21.383868+07
1271	agent-demo	hnth-branch-95	192.168.1.76	offline	237	75	0	2026-10-21 14:31:24.881+07	2026-10-21 14:31:24.886558+07
1272	agent-demo	hnth-branch-12	192.168.1.75	offline	232	75	0	2026-10-21 14:31:24.881+07	2026-10-21 14:31:24.888882+07
1275	agent-demo	hnth-branch-114	192.168.1.72	offline	243	75	0	2026-10-21 14:31:31.875+07	2026-10-21 14:31:31.884614+07
1276	agent-demo	hnth-branch-19	192.168.1.71	offline	239	75	0	2026-10-21 14:31:31.876+07	2026-10-21 14:31:31.888874+07
1277	agent-demo	hnth-branch-61	192.168.1.70	offline	241	75	0	2026-10-21 14:31:35.368+07	2026-10-21 14:31:35.371927+07
1278	agent-demo	hnth-branch-90	192.168.1.69	offline	231	75	0	2026-10-21 14:31:35.368+07	2026-10-21 14:31:35.373711+07
1279	agent-demo	hnth-branch-73	192.168.1.68	offline	239	75	0	2026-10-21 14:31:38.875+07	2026-10-21 14:31:38.879119+07
1280	agent-demo	hnth-branch-67	192.168.1.67	offline	235	75	0	2026-10-21 14:31:38.875+07	2026-10-21 14:31:38.880681+07
1283	agent-demo	hnth-branch-81	192.168.1.64	offline	238	75	0	2026-10-21 14:31:45.885+07	2026-10-21 14:31:45.893+07
1284	agent-demo	hnth-branch-39	192.168.1.63	offline	234	75	0	2026-10-21 14:31:45.885+07	2026-10-21 14:31:45.896272+07
1287	agent-demo	hnth-branch-53	192.168.1.60	offline	234	75	0	2026-10-21 14:31:52.867+07	2026-10-21 14:31:52.871295+07
1288	agent-demo	hnth-branch-43	192.168.1.59	offline	238	75	0	2026-10-21 14:31:52.867+07	2026-10-21 14:31:52.873383+07
1421	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 18:08:15.373+07	2026-10-21 18:08:15.381418+07
1434	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	\N	100	0	2026-10-21 18:42:51.367+07	2026-10-21 18:42:51.375107+07
1435	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	\N	100	0	2026-10-21 18:42:51.367+07	2026-10-21 18:42:51.377821+07
1436	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	212	75	0	2026-10-21 18:42:52.877+07	2026-10-21 18:42:52.881412+07
1437	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	222	75	0	2026-10-21 18:42:52.877+07	2026-10-21 18:42:52.883297+07
1442	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	236	75	0	2026-10-21 18:43:03.378+07	2026-10-21 18:43:03.385549+07
1443	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	227	75	0	2026-10-21 18:43:03.378+07	2026-10-21 18:43:03.389443+07
1444	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	241	75	0	2026-10-21 18:43:06.875+07	2026-10-21 18:43:06.878975+07
1445	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	232	75	0	2026-10-21 18:43:06.875+07	2026-10-21 18:43:06.880357+07
1446	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	240	75	0	2026-10-21 18:43:10.374+07	2026-10-21 18:43:10.382259+07
1447	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	212	75	0	2026-10-21 18:43:10.373+07	2026-10-21 18:43:10.386746+07
1448	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	213	75	0	2026-10-21 18:43:13.873+07	2026-10-21 18:43:13.877496+07
1449	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	235	75	0	2026-10-21 18:43:13.873+07	2026-10-21 18:43:13.879354+07
1452	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	238	75	0	2026-10-21 18:43:20.874+07	2026-10-21 18:43:20.878541+07
1453	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	226	75	0	2026-10-21 18:43:20.874+07	2026-10-21 18:43:20.880103+07
1458	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	228	75	0	2026-10-21 18:43:31.374+07	2026-10-21 18:43:31.381284+07
1459	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	242	75	0	2026-10-21 18:43:31.374+07	2026-10-21 18:43:31.383258+07
1460	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	251	75	0	2026-10-21 18:43:34.869+07	2026-10-21 18:43:34.874455+07
1461	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	234	75	0	2026-10-21 18:43:34.869+07	2026-10-21 18:43:34.875863+07
153	agent-demo	hnth-branch-16	192.168.1.87	online	239	75	0	2026-10-21 00:44:07.369+07	2026-10-21 00:44:07.375772+07
154	agent-demo	hnth-branch-17	192.168.1.93	online	231	75	0	2026-10-21 00:44:07.369+07	2026-10-21 00:44:07.378297+07
155	agent-demo	hnth-branch-18	192.168.1.120	online	235	75	0	2026-10-21 00:44:10.868+07	2026-10-21 00:44:10.8736+07
156	agent-demo	hnth-branch-19	192.168.1.71	online	243	75	0	2026-10-21 00:44:10.867+07	2026-10-21 00:44:10.876+07
157	agent-demo	hnth-branch-2	192.168.1.156	online	259	75	0	2026-10-21 00:44:14.378+07	2026-10-21 00:44:14.387052+07
158	agent-demo	hnth-branch-20	192.168.1.157	online	249	75	0	2026-10-21 00:44:14.378+07	2026-10-21 00:44:14.389147+07
159	agent-demo	hnth-branch-21	192.168.1.5	online	44	0	2.67	2026-10-21 00:44:15.337+07	2026-10-21 00:44:17.878404+07
160	agent-demo	hnth-branch-22	192.168.1.135	online	241	75	0	2026-10-21 00:44:17.873+07	2026-10-21 00:44:17.880944+07
161	agent-demo	hnth-branch-23	192.168.1.3	online	225	75	0	2026-10-21 00:44:21.378+07	2026-10-21 00:44:21.382739+07
162	agent-demo	hnth-branch-24	192.168.1.38	online	217	75	0	2026-10-21 00:44:21.378+07	2026-10-21 00:44:21.384902+07
163	agent-demo	hnth-branch-25	192.168.1.37	online	240	75	0	2026-10-21 00:44:24.875+07	2026-10-21 00:44:24.879184+07
164	agent-demo	hnth-branch-26	192.168.1.47	online	233	75	0	2026-10-21 00:44:24.875+07	2026-10-21 00:44:24.880498+07
167	agent-demo	hnth-branch-29	192.168.1.61	online	232	75	0	2026-10-21 00:44:31.874+07	2026-10-21 00:44:31.878014+07
168	agent-demo	hnth-branch-3	192.168.1.53	online	240	75	0	2026-10-21 00:44:31.874+07	2026-10-21 00:44:31.879281+07
169	agent-demo	hnth-branch-30	192.168.1.6	online	55	0	14	2026-10-21 00:44:32.865+07	2026-10-21 00:44:35.374685+07
170	agent-demo	hnth-branch-31	192.168.1.125	online	226	75	0	2026-10-21 00:44:35.371+07	2026-10-21 00:44:35.376107+07
1253	agent-demo	hnth-branch-85	192.168.1.95	offline	240	75	0	2026-10-21 14:30:53.372+07	2026-10-21 14:30:53.378521+07
1254	agent-demo	hnth-branch-41	192.168.1.94	offline	235	75	0	2026-10-21 14:30:53.372+07	2026-10-21 14:30:53.38148+07
1257	agent-demo	hnth-branch-15	192.168.1.91	offline	233	75	0	2026-10-21 14:31:00.376+07	2026-10-21 14:31:00.381412+07
1258	agent-demo	hnth-branch-49	192.168.1.90	offline	236	75	0	2026-10-21 14:31:00.375+07	2026-10-21 14:31:00.383009+07
1259	agent-demo	hnth-branch-104	192.168.1.89	offline	233	75	0	2026-10-21 14:31:03.873+07	2026-10-21 14:31:03.878035+07
1260	agent-demo	hnth-branch-16	192.168.1.87	offline	238	75	0	2026-10-21 14:31:03.873+07	2026-10-21 14:31:03.880357+07
1265	agent-demo	hnth-branch-74	192.168.1.82	offline	238	75	0	2026-10-21 14:31:14.369+07	2026-10-21 14:31:14.375002+07
1266	agent-demo	hnth-branch-9	192.168.1.81	offline	228	75	0	2026-10-21 14:31:14.369+07	2026-10-21 14:31:14.377296+07
1422	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	250	75	0	2026-10-21 18:08:20.873+07	2026-10-21 18:08:20.881708+07
1438	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	240	75	0	2026-10-21 18:42:56.379+07	2026-10-21 18:42:56.391614+07
1439	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	231	75	0	2026-10-21 18:42:56.379+07	2026-10-21 18:42:56.396319+07
1551	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 18:52:21.368+07	2026-10-21 18:52:21.376561+07
1591	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	233	75	0	2026-10-21 19:03:59.371+07	2026-10-21 19:03:59.380988+07
1592	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	243	75	0	2026-10-21 19:03:59.371+07	2026-10-21 19:03:59.383958+07
1593	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	234	75	0	2026-10-21 19:04:02.88+07	2026-10-21 19:04:02.886125+07
1594	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	244	75	0	2026-10-21 19:04:02.88+07	2026-10-21 19:04:02.888235+07
1597	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	235	75	0	2026-10-21 19:04:09.879+07	2026-10-21 19:04:09.883118+07
1598	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	238	75	0	2026-10-21 19:04:09.879+07	2026-10-21 19:04:09.884443+07
1651	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	236	75	0	2026-10-21 19:19:42.873+07	2026-10-21 19:19:42.879398+07
1652	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	243	75	0	2026-10-21 19:19:42.873+07	2026-10-21 19:19:42.881185+07
1653	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	223	75	0	2026-10-21 19:19:46.371+07	2026-10-21 19:19:46.379997+07
1654	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	217	75	0	2026-10-21 19:19:46.371+07	2026-10-21 19:19:46.382253+07
1655	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	240	75	0	2026-10-21 19:19:49.88+07	2026-10-21 19:19:49.89112+07
1656	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	229	75	0	2026-10-21 19:19:49.88+07	2026-10-21 19:19:49.892866+07
1659	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	239	75	0	2026-10-21 19:19:56.88+07	2026-10-21 19:19:56.884527+07
1660	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	230	75	0	2026-10-21 19:19:56.88+07	2026-10-21 19:19:56.885984+07
1667	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	238	75	0	2026-10-21 19:20:10.88+07	2026-10-21 19:20:10.885387+07
1668	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	227	75	0	2026-10-21 19:20:10.88+07	2026-10-21 19:20:10.887556+07
1673	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	242	75	0	2026-10-21 19:20:21.381+07	2026-10-21 19:20:21.385238+07
1674	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	231	75	0	2026-10-21 19:20:21.381+07	2026-10-21 19:20:21.386647+07
1675	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	245	75	0	2026-10-21 19:20:24.884+07	2026-10-21 19:20:24.889372+07
1676	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	238	75	0	2026-10-21 19:20:24.884+07	2026-10-21 19:20:24.890896+07
1679	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	40	0	20.67	2026-10-21 19:20:29.332+07	2026-10-21 19:20:31.872773+07
1680	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	243	75	0	2026-10-21 19:20:31.869+07	2026-10-21 19:20:31.874154+07
1683	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	230	75	0	2026-10-21 19:20:36.383+07	2026-10-21 19:20:36.389199+07
1684	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	241	75	0	2026-10-21 19:20:36.383+07	2026-10-21 19:20:36.391277+07
1687	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	236	75	0	2026-10-21 19:20:43.374+07	2026-10-21 19:20:43.378016+07
1688	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	240	75	0	2026-10-21 19:20:43.374+07	2026-10-21 19:20:43.379316+07
1689	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	237	75	0	2026-10-21 19:20:46.882+07	2026-10-21 19:20:46.8865+07
1690	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	230	75	0	2026-10-21 19:20:46.882+07	2026-10-21 19:20:46.887953+07
1693	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	228	75	0	2026-10-21 19:20:53.874+07	2026-10-21 19:20:53.877503+07
1694	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	204	75	0	2026-10-21 19:20:53.873+07	2026-10-21 19:20:53.878875+07
1699	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	236	75	0	2026-10-21 19:21:04.378+07	2026-10-21 19:21:04.873484+07
1700	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 19:21:04.87+07	2026-10-21 19:21:04.874919+07
1703	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 19:21:12.381+07	2026-10-21 19:21:12.384852+07
1704	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	82	0	37	2026-10-21 19:21:09.487+07	2026-10-21 19:21:12.386273+07
1709	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	44	0	16.67	2026-10-21 19:21:17.839+07	2026-10-21 19:21:20.379332+07
171	agent-demo	hnth-branch-32	192.168.1.121	online	241	75	0	2026-10-21 00:44:38.866+07	2026-10-21 00:44:38.870976+07
172	agent-demo	hnth-branch-33	192.168.1.126	online	232	75	0	2026-10-21 00:44:38.866+07	2026-10-21 00:44:38.873337+07
179	agent-demo	hnth-branch-4	192.168.1.7	online	51	0	4.67	2026-10-21 00:44:50.345+07	2026-10-21 00:44:52.881176+07
180	agent-demo	hnth-branch-40	192.168.1.16	online	225	75	0	2026-10-21 00:44:52.874+07	2026-10-21 00:44:52.883578+07
185	agent-demo	hnth-branch-45	192.168.1.55	online	241	75	0	2026-10-21 00:45:03.384+07	2026-10-21 00:45:03.390751+07
186	agent-demo	hnth-branch-46	192.168.1.2	online	53	0	12.67	2026-10-21 00:45:00.878+07	2026-10-21 00:45:03.393748+07
195	agent-demo	hnth-branch-54	192.168.1.74	online	239	75	0	2026-10-21 00:45:20.868+07	2026-10-21 00:45:20.873448+07
196	agent-demo	hnth-branch-55	192.168.1.54	online	231	75	0	2026-10-21 00:45:20.869+07	2026-10-21 00:45:20.875019+07
197	agent-demo	hnth-branch-56	192.168.1.36	online	226	75	0	2026-10-21 00:45:24.386+07	2026-10-21 00:45:24.394091+07
198	agent-demo	hnth-branch-57	192.168.1.57	online	215	75	0	2026-10-21 00:45:24.386+07	2026-10-21 00:45:24.401448+07
199	agent-demo	hnth-branch-58	192.168.1.14	online	229	75	0	2026-10-21 00:45:27.885+07	2026-10-21 00:45:27.892221+07
200	agent-demo	hnth-branch-59	192.168.1.114	online	239	75	0	2026-10-21 00:45:27.885+07	2026-10-21 00:45:27.895249+07
205	agent-demo	hnth-branch-63	192.168.1.104	online	227	75	0	2026-10-21 00:45:38.38+07	2026-10-21 00:45:38.390787+07
206	agent-demo	hnth-branch-64	192.168.1.113	online	217	75	0	2026-10-21 00:45:38.38+07	2026-10-21 00:45:38.394706+07
207	agent-demo	hnth-branch-65	192.168.1.45	online	248	75	0	2026-10-21 00:45:41.871+07	2026-10-21 00:45:41.877082+07
208	agent-demo	hnth-branch-66	192.168.1.9	online	255	75	0	2026-10-21 00:45:41.871+07	2026-10-21 00:45:41.881885+07
209	agent-demo	hnth-branch-67	192.168.1.67	online	240	75	0	2026-10-21 00:45:45.374+07	2026-10-21 00:45:45.379276+07
210	agent-demo	hnth-branch-68	192.168.1.103	online	231	75	0	2026-10-21 00:45:45.374+07	2026-10-21 00:45:45.382032+07
211	agent-demo	hnth-branch-69	192.168.1.1	online	56	0	15	2026-10-21 00:45:46.394+07	2026-10-21 00:45:48.961819+07
212	agent-demo	hnth-branch-7	192.168.1.41	online	237	75	0	2026-10-21 00:45:48.871+07	2026-10-21 00:45:48.966075+07
213	agent-demo	hnth-branch-70	192.168.1.106	online	240	75	0	2026-10-21 00:45:52.368+07	2026-10-21 00:45:52.375864+07
214	agent-demo	hnth-branch-72	192.168.1.83	online	229	75	0	2026-10-21 00:45:55.881+07	2026-10-21 00:45:55.888478+07
215	agent-demo	hnth-branch-73	192.168.1.68	online	238	75	0	2026-10-21 00:45:55.881+07	2026-10-21 00:45:55.891304+07
216	agent-demo	hnth-branch-74	192.168.1.82	online	243	75	0	2026-10-21 00:45:59.387+07	2026-10-21 00:45:59.393011+07
217	agent-demo	hnth-branch-75	192.168.1.108	online	234	75	0	2026-10-21 00:45:59.377+07	2026-10-21 00:45:59.395769+07
218	agent-demo	hnth-branch-76	192.168.1.66	online	240	75	0	2026-10-21 00:46:02.876+07	2026-10-21 00:46:02.884451+07
219	agent-demo	hnth-branch-77	192.168.1.49	online	56	0	16	2026-10-21 00:46:00.412+07	2026-10-21 00:46:02.886968+07
220	agent-demo	hnth-branch-78	192.168.1.102	online	241	75	0	2026-10-21 00:46:06.37+07	2026-10-21 00:46:06.878563+07
221	agent-demo	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 00:46:06.875+07	2026-10-21 00:46:06.87966+07
222	agent-demo	hnth-branch-8	192.168.1.80	online	243	75	0	2026-10-21 00:46:10.378+07	2026-10-21 00:46:10.876661+07
223	agent-demo	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 00:46:10.869+07	2026-10-21 00:46:10.879263+07
224	agent-demo	hnth-branch-81	192.168.1.64	online	226	75	0	2026-10-21 00:46:14.377+07	2026-10-21 00:46:14.386428+07
225	agent-demo	hnth-branch-82	192.168.1.40	online	244	75	0	2026-10-21 00:46:14.377+07	2026-10-21 00:46:14.389534+07
226	agent-demo	hnth-branch-83	192.168.1.105	online	256	75	0	2026-10-21 00:46:17.869+07	2026-10-21 00:46:17.87387+07
227	agent-demo	hnth-branch-84	192.168.1.62	online	247	75	0	2026-10-21 00:46:17.869+07	2026-10-21 00:46:17.876025+07
228	agent-demo	hnth-branch-85	192.168.1.95	online	241	75	0	2026-10-21 00:46:21.373+07	2026-10-21 00:46:21.376936+07
229	agent-demo	hnth-branch-86	192.168.1.99	online	231	75	0	2026-10-21 00:46:21.373+07	2026-10-21 00:46:21.378602+07
230	agent-demo	hnth-branch-87	192.168.1.15	online	240	75	0	2026-10-21 00:46:24.887+07	2026-10-21 00:46:24.89449+07
231	agent-demo	hnth-branch-88	192.168.1.43	online	231	75	0	2026-10-21 00:46:24.887+07	2026-10-21 00:46:24.898801+07
232	agent-demo	hnth-branch-89	192.168.1.124	online	241	75	0	2026-10-21 00:46:28.38+07	2026-10-21 00:46:28.383848+07
233	agent-demo	hnth-branch-9	192.168.1.81	online	232	75	0	2026-10-21 00:46:28.38+07	2026-10-21 00:46:28.385346+07
234	agent-demo	hnth-branch-90	192.168.1.69	online	233	75	0	2026-10-21 00:46:31.883+07	2026-10-21 00:46:31.887318+07
235	agent-demo	hnth-branch-91	192.168.1.97	online	240	75	0	2026-10-21 00:46:31.883+07	2026-10-21 00:46:31.88867+07
236	agent-demo	hnth-branch-92	192.168.1.107	online	238	75	0	2026-10-21 00:46:35.37+07	2026-10-21 00:46:35.374192+07
237	agent-demo	hnth-branch-93	192.168.1.122	online	230	75	0	2026-10-21 00:46:35.37+07	2026-10-21 00:46:35.376074+07
238	agent-demo	hnth-branch-94	192.168.1.98	online	225	75	0	2026-10-21 00:46:38.872+07	2026-10-21 00:46:38.876159+07
239	agent-demo	hnth-branch-95	192.168.1.76	online	217	75	0	2026-10-21 00:46:38.872+07	2026-10-21 00:46:38.877798+07
240	agent-demo	hnth-branch-96	192.168.1.100	online	249	75	0	2026-10-21 00:46:42.368+07	2026-10-21 00:46:42.372904+07
241	agent-demo	hnth-branch-97	192.168.1.110	online	257	75	0	2026-10-21 00:46:42.368+07	2026-10-21 00:46:42.374333+07
242	agent-demo	hnth-branch-98	192.168.1.10	online	230	75	0	2026-10-21 00:46:45.876+07	2026-10-21 00:46:45.882517+07
243	agent-demo	hnth-branch-99	192.168.1.48	online	239	75	0	2026-10-21 00:46:45.875+07	2026-10-21 00:46:45.885177+07
244	agent-demo	hnth-hub	192.168.1.169	online	239	75	0	2026-10-21 00:46:49.383+07	2026-10-21 00:46:49.387607+07
245	agent-demo	hnth-hub	192.168.1.169	online	258	75	0	2026-10-21 00:50:11.87+07	2026-10-21 00:50:11.878679+07
246	agent-demo	hnth-branch-79	192.168.1.11	online	129	0	30.33	2026-10-21 00:50:09.681+07	2026-10-21 00:50:11.890091+07
247	agent-demo	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 00:52:54.377+07	2026-10-21 00:52:54.382619+07
248	agent-demo	hnth-hub	192.168.1.169	online	259	75	0	2026-10-21 00:53:32.871+07	2026-10-21 00:53:33.380528+07
249	agent-demo	hnth-hub	192.168.1.169	online	248	75	0	2026-10-21 00:56:55.874+07	2026-10-21 00:56:56.387132+07
250	agent-demo	hnth-hub	192.168.1.169	online	224	75	0	2026-10-21 01:47:38.871+07	2026-10-21 01:47:38.878364+07
251	agent-demo	hnth-branch-110	192.168.1.159	online	215	75	0	2026-10-21 01:47:38.871+07	2026-10-21 01:47:38.880604+07
252	agent-demo	hnth-branch-13	192.168.1.158	online	242	75	0	2026-10-21 01:47:42.367+07	2026-10-21 01:47:42.373483+07
253	agent-demo	hnth-branch-20	192.168.1.157	online	235	75	0	2026-10-21 01:47:42.367+07	2026-10-21 01:47:42.374877+07
254	agent-demo	hnth-branch-2	192.168.1.156	online	232	75	0	2026-10-21 01:47:45.873+07	2026-10-21 01:47:45.878266+07
255	agent-demo	hnth-branch-38	192.168.1.155	online	239	75	0	2026-10-21 01:47:45.872+07	2026-10-21 01:47:45.881252+07
256	agent-demo	hnth-branch-35	192.168.1.161	online	226	75	0	2026-10-21 01:47:49.378+07	2026-10-21 01:47:49.383629+07
257	agent-demo	hnth-branch-33	192.168.1.126	online	199	75	0	2026-10-21 01:47:49.378+07	2026-10-21 01:47:49.385101+07
258	agent-demo	hnth-branch-31	192.168.1.125	online	215	75	0	2026-10-21 01:47:52.868+07	2026-10-21 01:47:52.872569+07
259	agent-demo	hnth-branch-89	192.168.1.124	online	224	75	0	2026-10-21 01:47:52.868+07	2026-10-21 01:47:52.873833+07
260	agent-demo	hnth-branch-34	192.168.1.123	online	255	75	0	2026-10-21 01:47:56.375+07	2026-10-21 01:47:56.382401+07
261	agent-demo	hnth-branch-93	192.168.1.122	online	247	75	0	2026-10-21 01:47:56.375+07	2026-10-21 01:47:56.384138+07
262	agent-demo	hnth-branch-32	192.168.1.121	online	257	75	0	2026-10-21 01:47:59.881+07	2026-10-21 01:47:59.885388+07
263	agent-demo	hnth-branch-18	192.168.1.120	online	249	75	0	2026-10-21 01:47:59.881+07	2026-10-21 01:47:59.88699+07
264	agent-demo	hnth-branch-1	192.168.1.160	online	43	0	2.67	2026-10-21 01:48:00.834+07	2026-10-21 01:48:03.372965+07
265	agent-demo	hnth-branch-108	192.168.1.118	online	257	75	0	2026-10-21 01:48:03.367+07	2026-10-21 01:48:03.375217+07
266	agent-demo	hnth-branch-42	192.168.1.117	online	233	75	0	2026-10-21 01:48:06.866+07	2026-10-21 01:48:06.870957+07
267	agent-demo	hnth-branch-62	192.168.1.116	online	241	75	0	2026-10-21 01:48:06.866+07	2026-10-21 01:48:06.872704+07
268	agent-demo	hnth-branch-69	192.168.1.1	online	45	0	4	2026-10-21 01:48:07.82+07	2026-10-21 01:48:10.373877+07
269	agent-demo	hnth-branch-59	192.168.1.114	online	241	75	0	2026-10-21 01:48:10.369+07	2026-10-21 01:48:10.375904+07
270	agent-demo	hnth-branch-64	192.168.1.113	online	222	75	0	2026-10-21 01:48:13.875+07	2026-10-21 01:48:13.879288+07
271	agent-demo	hnth-branch-27	192.168.1.112	online	213	75	0	2026-10-21 01:48:13.875+07	2026-10-21 01:48:13.88063+07
274	agent-demo	hnth-branch-106	192.168.1.109	online	230	75	0	2026-10-21 01:48:20.868+07	2026-10-21 01:48:20.873102+07
275	agent-demo	hnth-branch-75	192.168.1.108	online	239	75	0	2026-10-21 01:48:20.868+07	2026-10-21 01:48:20.874757+07
276	agent-demo	hnth-branch-92	192.168.1.107	online	233	75	0	2026-10-21 01:48:24.369+07	2026-10-21 01:48:24.373462+07
277	agent-demo	hnth-branch-70	192.168.1.106	online	242	75	0	2026-10-21 01:48:24.369+07	2026-10-21 01:48:24.374808+07
278	agent-demo	hnth-branch-83	192.168.1.105	online	239	75	0	2026-10-21 01:48:27.876+07	2026-10-21 01:48:27.880746+07
279	agent-demo	hnth-branch-63	192.168.1.104	online	230	75	0	2026-10-21 01:48:27.876+07	2026-10-21 01:48:27.88249+07
282	agent-demo	hnth-branch-14	192.168.1.101	online	217	75	0	2026-10-21 01:48:34.88+07	2026-10-21 01:48:34.88453+07
283	agent-demo	hnth-branch-96	192.168.1.100	online	225	75	0	2026-10-21 01:48:34.88+07	2026-10-21 01:48:34.886003+07
1273	agent-demo	hnth-branch-54	192.168.1.74	offline	238	75	0	2026-10-21 14:31:28.377+07	2026-10-21 14:31:28.390383+07
1274	agent-demo	hnth-branch-5	192.168.1.73	offline	234	75	0	2026-10-21 14:31:28.377+07	2026-10-21 14:31:28.393385+07
1281	agent-demo	hnth-branch-76	192.168.1.66	offline	244	75	0	2026-10-21 14:31:42.37+07	2026-10-21 14:31:42.374439+07
1282	agent-demo	hnth-branch-50	192.168.1.65	offline	239	75	0	2026-10-21 14:31:42.371+07	2026-10-21 14:31:42.377493+07
1285	agent-demo	hnth-branch-84	192.168.1.62	offline	239	75	0	2026-10-21 14:31:49.377+07	2026-10-21 14:31:49.381104+07
1286	agent-demo	hnth-branch-29	192.168.1.61	offline	202	75	0	2026-10-21 14:31:49.377+07	2026-10-21 14:31:49.382393+07
1289	agent-demo	hnth-branch-100	192.168.1.58	offline	242	75	0	2026-10-21 14:31:56.378+07	2026-10-21 14:31:56.381694+07
1290	agent-demo	hnth-branch-57	192.168.1.57	offline	238	75	0	2026-10-21 14:31:56.378+07	2026-10-21 14:31:56.382983+07
1291	agent-demo	hnth-branch-109	192.168.1.56	offline	232	75	0	2026-10-21 14:31:59.881+07	2026-10-21 14:31:59.888189+07
1292	agent-demo	hnth-branch-45	192.168.1.55	offline	238	75	0	2026-10-21 14:31:59.881+07	2026-10-21 14:31:59.89275+07
1293	agent-demo	hnth-branch-55	192.168.1.54	offline	238	75	0	2026-10-21 14:32:03.377+07	2026-10-21 14:32:03.380971+07
1294	agent-demo	hnth-branch-3	192.168.1.53	offline	228	75	0	2026-10-21 14:32:03.377+07	2026-10-21 14:32:03.383316+07
1295	agent-demo	hnth-branch-111	192.168.1.52	online	40	0	8.67	2026-10-21 14:32:04.327+07	2026-10-21 14:32:06.887051+07
1296	agent-demo	hnth-branch-36	192.168.1.51	offline	224	75	0	2026-10-21 14:32:06.879+07	2026-10-21 14:32:06.89102+07
1299	agent-demo	hnth-branch-99	192.168.1.48	offline	235	75	0	2026-10-21 14:32:11.377+07	2026-10-21 14:32:11.380365+07
1300	agent-demo	hnth-branch-26	192.168.1.47	offline	238	75	0	2026-10-21 14:32:11.377+07	2026-10-21 14:32:11.381715+07
1423	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 18:11:30.865+07	2026-10-21 18:11:30.87171+07
1440	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	237	75	0	2026-10-21 18:42:59.866+07	2026-10-21 18:42:59.876036+07
1441	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	212	75	0	2026-10-21 18:42:59.866+07	2026-10-21 18:42:59.878016+07
1450	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	47	0	12	2026-10-21 18:43:14.831+07	2026-10-21 18:43:17.390001+07
1451	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	236	75	0	2026-10-21 18:43:17.381+07	2026-10-21 18:43:17.39303+07
1454	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	69	0	26	2026-10-21 18:43:21.927+07	2026-10-21 18:43:24.382253+07
1455	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	236	75	0	2026-10-21 18:43:24.377+07	2026-10-21 18:43:24.384457+07
1456	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	214	75	0	2026-10-21 18:43:27.874+07	2026-10-21 18:43:27.878242+07
1457	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	234	75	0	2026-10-21 18:43:27.874+07	2026-10-21 18:43:27.879582+07
1462	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	239	75	0	2026-10-21 18:43:38.375+07	2026-10-21 18:43:38.384267+07
1463	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	231	75	0	2026-10-21 18:43:38.375+07	2026-10-21 18:43:38.385643+07
1466	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	239	75	0	2026-10-21 18:43:45.375+07	2026-10-21 18:43:45.38098+07
1467	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	230	75	0	2026-10-21 18:43:45.375+07	2026-10-21 18:43:45.383658+07
1468	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	238	75	0	2026-10-21 18:43:48.877+07	2026-10-21 18:43:48.88096+07
1469	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	231	75	0	2026-10-21 18:43:48.877+07	2026-10-21 18:43:48.882342+07
1552	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	232	75	0	2026-10-21 18:55:28.373+07	2026-10-21 18:55:28.379542+07
1599	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 19:18:11.877+07	2026-10-21 19:18:11.892605+07
1600	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	242	75	0	2026-10-21 19:18:11.878+07	2026-10-21 19:18:11.919069+07
1603	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	239	75	0	2026-10-21 19:18:18.873+07	2026-10-21 19:18:18.877335+07
1604	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	228	75	0	2026-10-21 19:18:18.873+07	2026-10-21 19:18:18.878986+07
1607	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	239	75	0	2026-10-21 19:18:25.871+07	2026-10-21 19:18:25.875551+07
1608	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	227	75	0	2026-10-21 19:18:25.871+07	2026-10-21 19:18:25.87697+07
1609	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	233	75	0	2026-10-21 19:18:29.379+07	2026-10-21 19:18:29.38747+07
1610	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	243	75	0	2026-10-21 19:18:29.38+07	2026-10-21 19:18:29.390899+07
1672	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	238	75	0	2026-10-21 19:20:17.879+07	2026-10-21 19:20:17.891945+07
1677	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	239	75	0	2026-10-21 19:20:28.378+07	2026-10-21 19:20:28.382599+07
1678	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	229	75	0	2026-10-21 19:20:28.378+07	2026-10-21 19:20:28.384107+07
1681	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	45	0	27.67	2026-10-21 19:20:32.839+07	2026-10-21 19:20:32.842667+07
1682	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	41	0	21.33	2026-10-21 19:20:32.835+07	2026-10-21 19:20:32.843976+07
1685	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	246	75	0	2026-10-21 19:20:39.882+07	2026-10-21 19:20:39.886303+07
1686	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	242	75	0	2026-10-21 19:20:39.882+07	2026-10-21 19:20:39.887712+07
1691	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	239	75	0	2026-10-21 19:20:50.379+07	2026-10-21 19:20:50.382852+07
1692	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	233	75	0	2026-10-21 19:20:50.379+07	2026-10-21 19:20:50.384359+07
1695	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	241	75	0	2026-10-21 19:20:57.378+07	2026-10-21 19:20:57.386539+07
1696	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	237	75	0	2026-10-21 19:20:57.377+07	2026-10-21 19:20:57.389375+07
1697	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	229	75	0	2026-10-21 19:21:00.877+07	2026-10-21 19:21:00.881788+07
272	agent-demo	hnth-branch-107	192.168.1.111	online	239	75	0	2026-10-21 01:48:17.368+07	2026-10-21 01:48:17.37228+07
273	agent-demo	hnth-branch-97	192.168.1.110	online	231	75	0	2026-10-21 01:48:17.368+07	2026-10-21 01:48:17.373662+07
280	agent-demo	hnth-branch-68	192.168.1.103	online	239	75	0	2026-10-21 01:48:31.37+07	2026-10-21 01:48:31.375092+07
281	agent-demo	hnth-branch-78	192.168.1.102	online	232	75	0	2026-10-21 01:48:31.37+07	2026-10-21 01:48:31.37649+07
284	agent-demo	hnth-branch-86	192.168.1.99	online	256	75	0	2026-10-21 01:48:38.37+07	2026-10-21 01:48:38.374906+07
285	agent-demo	hnth-branch-94	192.168.1.98	online	248	75	0	2026-10-21 01:48:38.37+07	2026-10-21 01:48:38.376924+07
286	agent-demo	hnth-branch-91	192.168.1.97	online	230	75	0	2026-10-21 01:48:41.879+07	2026-10-21 01:48:41.886814+07
287	agent-demo	hnth-branch-11	192.168.1.96	online	239	75	0	2026-10-21 01:48:41.879+07	2026-10-21 01:48:41.889271+07
288	agent-demo	hnth-branch-85	192.168.1.95	online	218	75	0	2026-10-21 01:48:45.377+07	2026-10-21 01:48:45.386454+07
289	agent-demo	hnth-branch-41	192.168.1.94	online	226	75	0	2026-10-21 01:48:45.377+07	2026-10-21 01:48:45.388037+07
290	agent-demo	hnth-branch-17	192.168.1.93	online	232	75	0	2026-10-21 01:48:48.878+07	2026-10-21 01:48:48.882332+07
291	agent-demo	hnth-branch-6	192.168.1.92	online	241	75	0	2026-10-21 01:48:48.878+07	2026-10-21 01:48:48.883536+07
292	agent-demo	hnth-branch-15	192.168.1.91	online	223	75	0	2026-10-21 01:48:52.376+07	2026-10-21 01:48:52.380821+07
293	agent-demo	hnth-branch-49	192.168.1.90	online	215	75	0	2026-10-21 01:48:52.375+07	2026-10-21 01:48:52.382452+07
294	agent-demo	hnth-branch-104	192.168.1.89	online	234	75	0	2026-10-21 01:48:55.876+07	2026-10-21 01:48:55.881739+07
295	agent-demo	hnth-branch-16	192.168.1.87	online	242	75	0	2026-10-21 01:48:55.876+07	2026-10-21 01:48:55.883941+07
296	agent-demo	hnth-branch-60	192.168.1.86	online	232	75	0	2026-10-21 01:48:59.367+07	2026-10-21 01:48:59.374178+07
297	agent-demo	hnth-branch-48	192.168.1.85	online	241	75	0	2026-10-21 01:48:59.369+07	2026-10-21 01:48:59.376333+07
298	agent-demo	hnth-branch-10	192.168.1.84	online	255	75	0	2026-10-21 01:49:02.87+07	2026-10-21 01:49:02.873675+07
299	agent-demo	hnth-branch-72	192.168.1.83	online	247	75	0	2026-10-21 01:49:02.87+07	2026-10-21 01:49:02.875018+07
300	agent-demo	hnth-branch-74	192.168.1.82	online	231	75	0	2026-10-21 01:49:06.372+07	2026-10-21 01:49:06.375866+07
301	agent-demo	hnth-branch-9	192.168.1.81	online	240	75	0	2026-10-21 01:49:06.372+07	2026-10-21 01:49:06.377074+07
302	agent-demo	hnth-branch-8	192.168.1.80	online	236	75	0	2026-10-21 01:49:09.879+07	2026-10-21 01:49:09.883414+07
303	agent-demo	hnth-branch-103	192.168.1.79	online	245	75	0	2026-10-21 01:49:09.879+07	2026-10-21 01:49:09.884608+07
304	agent-demo	hnth-branch-52	192.168.1.78	online	240	75	0	2026-10-21 01:49:13.377+07	2026-10-21 01:49:13.381002+07
305	agent-demo	hnth-branch-44	192.168.1.77	online	233	75	0	2026-10-21 01:49:13.377+07	2026-10-21 01:49:13.382367+07
306	agent-demo	hnth-branch-95	192.168.1.76	online	230	75	0	2026-10-21 01:49:16.88+07	2026-10-21 01:49:16.884814+07
307	agent-demo	hnth-branch-12	192.168.1.75	online	239	75	0	2026-10-21 01:49:16.88+07	2026-10-21 01:49:16.886066+07
308	agent-demo	hnth-branch-54	192.168.1.74	online	232	75	0	2026-10-21 01:49:20.378+07	2026-10-21 01:49:20.382381+07
309	agent-demo	hnth-branch-5	192.168.1.73	online	239	75	0	2026-10-21 01:49:20.378+07	2026-10-21 01:49:20.38422+07
310	agent-demo	hnth-branch-114	192.168.1.72	online	248	75	0	2026-10-21 01:49:23.868+07	2026-10-21 01:49:23.871386+07
311	agent-demo	hnth-branch-19	192.168.1.71	online	240	75	0	2026-10-21 01:49:23.867+07	2026-10-21 01:49:23.872921+07
312	agent-demo	hnth-branch-61	192.168.1.70	online	253	75	0	2026-10-21 01:49:27.372+07	2026-10-21 01:49:27.375894+07
313	agent-demo	hnth-branch-90	192.168.1.69	online	245	75	0	2026-10-21 01:49:27.372+07	2026-10-21 01:49:27.377043+07
314	agent-demo	hnth-branch-73	192.168.1.68	online	229	75	0	2026-10-21 01:49:30.879+07	2026-10-21 01:49:30.886396+07
315	agent-demo	hnth-branch-67	192.168.1.67	online	256	75	0	2026-10-21 01:49:30.879+07	2026-10-21 01:49:30.889106+07
316	agent-demo	hnth-branch-76	192.168.1.66	online	240	75	0	2026-10-21 01:49:34.383+07	2026-10-21 01:49:34.394603+07
317	agent-demo	hnth-branch-50	192.168.1.65	online	232	75	0	2026-10-21 01:49:34.383+07	2026-10-21 01:49:34.396753+07
318	agent-demo	hnth-branch-81	192.168.1.64	online	240	75	0	2026-10-21 01:49:37.884+07	2026-10-21 01:49:37.893142+07
319	agent-demo	hnth-branch-39	192.168.1.63	online	230	75	0	2026-10-21 01:49:37.884+07	2026-10-21 01:49:37.897236+07
320	agent-demo	hnth-branch-84	192.168.1.62	online	241	75	0	2026-10-21 01:49:41.379+07	2026-10-21 01:49:41.383398+07
321	agent-demo	hnth-branch-29	192.168.1.61	online	232	75	0	2026-10-21 01:49:41.379+07	2026-10-21 01:49:41.384628+07
322	agent-demo	hnth-branch-53	192.168.1.60	online	246	75	0	2026-10-21 01:49:44.882+07	2026-10-21 01:49:44.890126+07
323	agent-demo	hnth-branch-43	192.168.1.59	online	255	75	0	2026-10-21 01:49:44.882+07	2026-10-21 01:49:44.892187+07
324	agent-demo	hnth-branch-100	192.168.1.58	online	261	75	0	2026-10-21 01:49:48.379+07	2026-10-21 01:49:48.383154+07
325	agent-demo	hnth-branch-57	192.168.1.57	online	253	75	0	2026-10-21 01:49:48.379+07	2026-10-21 01:49:48.384746+07
326	agent-demo	hnth-branch-109	192.168.1.56	online	214	75	0	2026-10-21 01:49:51.877+07	2026-10-21 01:49:51.881268+07
327	agent-demo	hnth-branch-45	192.168.1.55	online	241	75	0	2026-10-21 01:49:51.877+07	2026-10-21 01:49:51.88266+07
328	agent-demo	hnth-branch-55	192.168.1.54	online	220	75	0	2026-10-21 01:49:55.369+07	2026-10-21 01:49:55.373519+07
329	agent-demo	hnth-branch-3	192.168.1.53	online	210	75	0	2026-10-21 01:49:55.369+07	2026-10-21 01:49:55.374719+07
330	agent-demo	hnth-branch-111	192.168.1.52	online	47	0	7	2026-10-21 01:49:56.339+07	2026-10-21 01:49:58.879941+07
331	agent-demo	hnth-branch-36	192.168.1.51	online	234	75	0	2026-10-21 01:49:58.873+07	2026-10-21 01:49:58.883041+07
332	agent-demo	hnth-branch-47	192.168.1.50	online	62	0	22.67	2026-10-21 01:49:59.902+07	2026-10-21 01:49:59.916631+07
333	agent-demo	hnth-branch-77	192.168.1.49	online	59	0	19	2026-10-21 01:49:59.911+07	2026-10-21 01:49:59.919593+07
334	agent-demo	hnth-branch-99	192.168.1.48	online	237	75	0	2026-10-21 01:50:03.376+07	2026-10-21 01:50:03.380436+07
335	agent-demo	hnth-branch-26	192.168.1.47	online	229	75	0	2026-10-21 01:50:03.376+07	2026-10-21 01:50:03.38215+07
336	agent-demo	hnth-branch-112	192.168.1.46	online	230	75	0	2026-10-21 01:50:06.87+07	2026-10-21 01:50:06.874739+07
337	agent-demo	hnth-branch-65	192.168.1.45	online	238	75	0	2026-10-21 01:50:06.87+07	2026-10-21 01:50:06.876161+07
338	agent-demo	hnth-branch-113	192.168.1.44	online	239	75	0	2026-10-21 01:50:10.379+07	2026-10-21 01:50:10.383742+07
339	agent-demo	hnth-branch-88	192.168.1.43	online	231	75	0	2026-10-21 01:50:10.379+07	2026-10-21 01:50:10.385949+07
340	agent-demo	hnth-branch-102	192.168.1.42	online	232	75	0	2026-10-21 01:50:13.873+07	2026-10-21 01:50:13.87772+07
341	agent-demo	hnth-branch-7	192.168.1.41	online	244	75	0	2026-10-21 01:50:13.873+07	2026-10-21 01:50:13.87911+07
342	agent-demo	hnth-branch-82	192.168.1.40	online	242	75	0	2026-10-21 01:50:17.371+07	2026-10-21 01:50:17.374945+07
343	agent-demo	hnth-branch-51	192.168.1.39	online	235	75	0	2026-10-21 01:50:17.371+07	2026-10-21 01:50:17.37646+07
344	agent-demo	hnth-branch-24	192.168.1.38	online	251	75	0	2026-10-21 01:50:20.872+07	2026-10-21 01:50:20.876822+07
345	agent-demo	hnth-branch-25	192.168.1.37	online	259	75	0	2026-10-21 01:50:20.872+07	2026-10-21 01:50:20.878166+07
346	agent-demo	hnth-branch-56	192.168.1.36	online	244	75	0	2026-10-21 01:50:24.876+07	2026-10-21 01:50:24.883597+07
347	agent-demo	hnth-branch-87	192.168.1.15	online	231	75	0	2026-10-21 01:50:24.876+07	2026-10-21 01:50:24.885472+07
348	agent-demo	hnth-branch-58	192.168.1.14	online	217	75	0	2026-10-21 01:50:28.375+07	2026-10-21 01:50:28.382599+07
349	agent-demo	hnth-branch-105	192.168.1.13	online	229	75	0	2026-10-21 01:50:28.375+07	2026-10-21 01:50:28.384567+07
350	agent-demo	hnth-branch-101	192.168.1.12	online	247	75	0	2026-10-21 01:50:31.873+07	2026-10-21 01:50:32.39003+07
351	agent-demo	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 01:50:32.385+07	2026-10-21 01:50:32.392083+07
352	agent-demo	hnth-branch-98	192.168.1.10	online	231	75	0	2026-10-21 01:50:35.868+07	2026-10-21 01:50:35.872293+07
353	agent-demo	hnth-branch-66	192.168.1.9	online	241	75	0	2026-10-21 01:50:35.868+07	2026-10-21 01:50:35.873522+07
354	agent-demo	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 01:50:39.875+07	2026-10-21 01:50:39.879749+07
355	agent-demo	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 01:50:39.875+07	2026-10-21 01:50:39.881035+07
358	agent-demo	hnth-branch-28	192.168.1.4	online	51	0	16.67	2026-10-21 01:50:41.837+07	2026-10-21 01:50:44.38068+07
359	agent-demo	hnth-branch-23	192.168.1.3	online	240	75	0	2026-10-21 01:50:44.376+07	2026-10-21 01:50:44.382007+07
362	agent-demo	hnth-branch-37	192.168.1.0	online	241	75	0	2026-10-21 01:50:51.373+07	2026-10-21 01:50:51.378352+07
363	agent-demo	hnth-branch-40	192.168.1.16	online	233	75	0	2026-10-21 01:50:51.373+07	2026-10-21 01:50:51.380341+07
1297	agent-demo	hnth-branch-47	192.168.1.50	online	43	0	7.67	2026-10-21 14:32:07.836+07	2026-10-21 14:32:07.846744+07
1298	agent-demo	hnth-branch-77	192.168.1.49	online	41	0	4.33	2026-10-21 14:32:07.841+07	2026-10-21 14:32:07.864896+07
1301	agent-demo	hnth-branch-112	192.168.1.46	offline	239	75	0	2026-10-21 14:32:14.874+07	2026-10-21 14:32:14.877458+07
1302	agent-demo	hnth-branch-65	192.168.1.45	offline	234	75	0	2026-10-21 14:32:14.874+07	2026-10-21 14:32:14.878877+07
1303	agent-demo	hnth-branch-113	192.168.1.44	offline	247	75	0	2026-10-21 14:32:18.384+07	2026-10-21 14:32:18.391533+07
1304	agent-demo	hnth-branch-88	192.168.1.43	offline	243	75	0	2026-10-21 14:32:18.385+07	2026-10-21 14:32:18.394818+07
1424	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	219	75	0	2026-10-21 18:14:39.883+07	2026-10-21 18:14:39.889452+07
1425	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 18:17:48.867+07	2026-10-21 18:17:48.871994+07
1426	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	230	75	0	2026-10-21 18:20:57.869+07	2026-10-21 18:20:57.873287+07
1427	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-21 18:24:06.87+07	2026-10-21 18:24:07.377684+07
1464	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	245	75	0	2026-10-21 18:43:41.878+07	2026-10-21 18:43:41.881801+07
1465	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	253	75	0	2026-10-21 18:43:41.878+07	2026-10-21 18:43:41.883362+07
1470	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	244	75	0	2026-10-21 18:43:52.369+07	2026-10-21 18:43:52.37564+07
1471	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	226	75	0	2026-10-21 18:43:52.369+07	2026-10-21 18:43:52.378282+07
1472	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	237	75	0	2026-10-21 18:43:55.871+07	2026-10-21 18:43:55.874532+07
1473	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	221	75	0	2026-10-21 18:43:55.871+07	2026-10-21 18:43:55.875914+07
1476	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	228	75	0	2026-10-21 18:44:02.877+07	2026-10-21 18:44:02.881673+07
1477	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	239	75	0	2026-10-21 18:44:02.878+07	2026-10-21 18:44:02.883078+07
1482	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	239	75	0	2026-10-21 18:44:13.375+07	2026-10-21 18:44:13.379361+07
1483	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	229	75	0	2026-10-21 18:44:13.375+07	2026-10-21 18:44:13.380916+07
1486	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	232	75	0	2026-10-21 18:44:20.37+07	2026-10-21 18:44:20.374624+07
1487	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	240	75	0	2026-10-21 18:44:20.37+07	2026-10-21 18:44:20.375857+07
1492	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	240	75	0	2026-10-21 18:44:30.874+07	2026-10-21 18:44:30.878128+07
1493	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	230	75	0	2026-10-21 18:44:30.874+07	2026-10-21 18:44:30.879512+07
1496	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	240	75	0	2026-10-21 18:44:37.88+07	2026-10-21 18:44:37.884128+07
1497	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	232	75	0	2026-10-21 18:44:37.88+07	2026-10-21 18:44:37.88675+07
1500	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	223	75	0	2026-10-21 18:44:44.866+07	2026-10-21 18:44:44.870875+07
1501	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	237	75	0	2026-10-21 18:44:44.866+07	2026-10-21 18:44:44.872375+07
1504	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	237	75	0	2026-10-21 18:44:51.878+07	2026-10-21 18:44:51.882138+07
1505	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	205	75	0	2026-10-21 18:44:51.878+07	2026-10-21 18:44:51.883375+07
1506	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	242	75	0	2026-10-21 18:44:55.384+07	2026-10-21 18:44:55.393806+07
1507	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	231	75	0	2026-10-21 18:44:55.384+07	2026-10-21 18:44:55.398627+07
1512	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	228	75	0	2026-10-21 18:45:05.872+07	2026-10-21 18:45:05.876179+07
1513	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	215	75	0	2026-10-21 18:45:05.872+07	2026-10-21 18:45:05.877497+07
1516	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	88	0	35.33	2026-10-21 18:45:10.532+07	2026-10-21 18:45:12.871099+07
1517	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	239	75	0	2026-10-21 18:45:12.866+07	2026-10-21 18:45:12.872518+07
1520	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	239	75	0	2026-10-21 18:45:17.375+07	2026-10-21 18:45:17.380056+07
1521	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	224	75	0	2026-10-21 18:45:17.375+07	2026-10-21 18:45:17.381884+07
1524	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	244	75	0	2026-10-21 18:45:24.368+07	2026-10-21 18:45:24.372106+07
1525	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	295	75	0	2026-10-21 18:45:24.368+07	2026-10-21 18:45:24.373494+07
1526	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	237	75	0	2026-10-21 18:45:27.868+07	2026-10-21 18:45:27.874067+07
1527	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	220	75	0	2026-10-21 18:45:27.87+07	2026-10-21 18:45:27.87531+07
1530	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	234	75	0	2026-10-21 18:45:34.871+07	2026-10-21 18:45:34.876295+07
1531	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	217	75	0	2026-10-21 18:45:34.871+07	2026-10-21 18:45:34.877757+07
1534	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	237	75	0	2026-10-21 18:45:41.876+07	2026-10-21 18:45:41.880151+07
1535	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	218	75	0	2026-10-21 18:45:41.876+07	2026-10-21 18:45:41.881553+07
1538	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	231	75	0	2026-10-21 18:45:49.369+07	2026-10-21 18:45:49.373372+07
1539	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	239	75	0	2026-10-21 18:45:49.368+07	2026-10-21 18:45:49.376642+07
1542	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	50	0	9	2026-10-21 18:45:53.858+07	2026-10-21 18:45:53.86199+07
1543	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	44	0	6.67	2026-10-21 18:45:53.858+07	2026-10-21 18:45:53.863285+07
1544	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	52	0	12	2026-10-21 18:45:54.851+07	2026-10-21 18:45:57.384357+07
1545	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	242	75	0	2026-10-21 18:45:57.378+07	2026-10-21 18:45:57.385748+07
1548	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	237	75	0	2026-10-21 18:46:04.367+07	2026-10-21 18:46:04.371591+07
1549	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	213	75	0	2026-10-21 18:46:04.367+07	2026-10-21 18:46:04.372946+07
1553	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	232	75	0	2026-10-21 18:58:35.374+07	2026-10-21 18:58:35.38724+07
1601	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	233	75	0	2026-10-21 19:18:15.376+07	2026-10-21 19:18:15.390135+07
356	agent-demo	hnth-branch-30	192.168.1.6	online	46	0	2.33	2026-10-21 01:50:40.833+07	2026-10-21 01:50:40.845574+07
357	agent-demo	hnth-branch-21	192.168.1.5	online	46	0	1.67	2026-10-21 01:50:40.841+07	2026-10-21 01:50:40.84674+07
360	agent-demo	hnth-branch-46	192.168.1.2	online	44	0	4.67	2026-10-21 01:50:45.333+07	2026-10-21 01:50:47.880313+07
361	agent-demo	hnth-branch-22	192.168.1.135	online	224	75	0	2026-10-21 01:50:47.876+07	2026-10-21 01:50:47.881881+07
364	agent-demo	hnth-hub	192.168.1.169	online	232	75	0	2026-10-21 01:50:57.869+07	2026-10-21 01:50:58.38147+07
365	agent-demo	hnth-hub	192.168.1.169	online	231	75	0	2026-10-21 01:57:33.372+07	2026-10-21 01:57:33.895637+07
366	agent-demo	hnth-branch-98	192.168.1.10	offline	\N	100	0	2026-10-21 02:00:33.374+07	2026-10-21 02:00:33.39162+07
367	agent-demo	hnth-branch-66	192.168.1.9	offline	\N	100	0	2026-10-21 02:00:32.888+07	2026-10-21 02:00:33.394883+07
368	agent-demo	hnth-branch-4	192.168.1.7	online	122	0	31.67	2026-10-21 02:00:50.643+07	2026-10-21 02:00:52.87685+07
369	agent-demo	hnth-hub	192.168.1.169	online	243	75	0	2026-10-21 02:00:52.872+07	2026-10-21 02:00:52.879319+07
370	agent-demo	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 02:03:49.868+07	2026-10-21 02:03:49.873919+07
371	agent-demo	hnth-branch-98	192.168.1.10	online	238	75	0	2026-10-21 02:04:04.871+07	2026-10-21 02:04:05.383995+07
372	agent-demo	hnth-branch-66	192.168.1.9	online	229	75	0	2026-10-21 02:04:08.87+07	2026-10-21 02:04:09.386619+07
373	agent-demo	hnth-hub	192.168.1.169	online	232	75	0	2026-10-21 02:04:12.877+07	2026-10-21 02:04:12.881462+07
374	agent-demo	hnth-hub	192.168.1.169	online	243	75	0	2026-10-21 08:21:24.872+07	2026-10-21 08:21:24.880246+07
375	agent-demo	hnth-branch-110	192.168.1.159	online	230	75	0	2026-10-21 08:21:24.871+07	2026-10-21 08:21:24.891376+07
376	agent-demo	hnth-branch-13	192.168.1.158	online	235	75	0	2026-10-21 08:21:28.367+07	2026-10-21 08:21:28.371402+07
377	agent-demo	hnth-branch-20	192.168.1.157	online	224	75	0	2026-10-21 08:21:28.367+07	2026-10-21 08:21:28.37378+07
378	agent-demo	hnth-branch-2	192.168.1.156	online	224	75	0	2026-10-21 08:21:31.871+07	2026-10-21 08:21:31.875017+07
379	agent-demo	hnth-branch-38	192.168.1.155	online	214	75	0	2026-10-21 08:21:31.871+07	2026-10-21 08:21:31.876756+07
380	agent-demo	hnth-branch-35	192.168.1.161	online	227	75	0	2026-10-21 08:21:35.382+07	2026-10-21 08:21:35.388943+07
381	agent-demo	hnth-branch-33	192.168.1.126	online	217	75	0	2026-10-21 08:21:35.381+07	2026-10-21 08:21:35.391353+07
382	agent-demo	hnth-branch-31	192.168.1.125	online	231	75	0	2026-10-21 08:21:38.88+07	2026-10-21 08:21:38.884207+07
383	agent-demo	hnth-branch-89	192.168.1.124	online	242	75	0	2026-10-21 08:21:38.88+07	2026-10-21 08:21:38.886171+07
384	agent-demo	hnth-branch-34	192.168.1.123	online	213	75	0	2026-10-21 08:21:42.367+07	2026-10-21 08:21:42.374877+07
385	agent-demo	hnth-branch-93	192.168.1.122	online	224	75	0	2026-10-21 08:21:42.368+07	2026-10-21 08:21:42.377101+07
386	agent-demo	hnth-branch-32	192.168.1.121	online	239	75	0	2026-10-21 08:21:45.869+07	2026-10-21 08:21:45.874111+07
387	agent-demo	hnth-branch-18	192.168.1.120	online	227	75	0	2026-10-21 08:21:45.869+07	2026-10-21 08:21:45.876056+07
388	agent-demo	hnth-branch-1	192.168.1.160	online	65	0	6.33	2026-10-21 08:21:46.915+07	2026-10-21 08:21:49.379264+07
389	agent-demo	hnth-branch-108	192.168.1.118	online	241	75	0	2026-10-21 08:21:49.375+07	2026-10-21 08:21:49.38087+07
390	agent-demo	hnth-branch-42	192.168.1.117	online	245	75	0	2026-10-21 08:21:52.872+07	2026-10-21 08:21:52.87633+07
391	agent-demo	hnth-branch-62	192.168.1.116	online	237	75	0	2026-10-21 08:21:52.872+07	2026-10-21 08:21:52.878112+07
392	agent-demo	hnth-branch-69	192.168.1.1	online	62	0	6	2026-10-21 08:21:53.901+07	2026-10-21 08:21:56.377027+07
393	agent-demo	hnth-branch-59	192.168.1.114	online	241	75	0	2026-10-21 08:21:56.37+07	2026-10-21 08:21:56.379289+07
394	agent-demo	hnth-branch-64	192.168.1.113	online	226	75	0	2026-10-21 08:21:59.879+07	2026-10-21 08:21:59.882395+07
395	agent-demo	hnth-branch-27	192.168.1.112	online	199	75	0	2026-10-21 08:21:59.879+07	2026-10-21 08:21:59.883604+07
396	agent-demo	hnth-branch-107	192.168.1.111	online	230	75	0	2026-10-21 08:22:03.377+07	2026-10-21 08:22:03.380663+07
397	agent-demo	hnth-branch-97	192.168.1.110	online	260	75	0	2026-10-21 08:22:03.377+07	2026-10-21 08:22:03.381965+07
398	agent-demo	hnth-branch-106	192.168.1.109	online	231	75	0	2026-10-21 08:22:06.874+07	2026-10-21 08:22:06.878079+07
399	agent-demo	hnth-branch-75	192.168.1.108	online	240	75	0	2026-10-21 08:22:06.874+07	2026-10-21 08:22:06.880023+07
400	agent-demo	hnth-branch-92	192.168.1.107	online	242	75	0	2026-10-21 08:22:10.375+07	2026-10-21 08:22:10.379372+07
401	agent-demo	hnth-branch-70	192.168.1.106	online	232	75	0	2026-10-21 08:22:10.375+07	2026-10-21 08:22:10.380895+07
402	agent-demo	hnth-branch-83	192.168.1.105	online	238	75	0	2026-10-21 08:22:13.875+07	2026-10-21 08:22:13.879298+07
403	agent-demo	hnth-branch-63	192.168.1.104	online	228	75	0	2026-10-21 08:22:13.875+07	2026-10-21 08:22:13.88068+07
404	agent-demo	hnth-branch-68	192.168.1.103	online	241	75	0	2026-10-21 08:22:17.377+07	2026-10-21 08:22:17.384401+07
405	agent-demo	hnth-branch-78	192.168.1.102	online	230	75	0	2026-10-21 08:22:17.377+07	2026-10-21 08:22:17.386209+07
406	agent-demo	hnth-branch-14	192.168.1.101	online	230	75	0	2026-10-21 08:22:20.876+07	2026-10-21 08:22:20.880607+07
407	agent-demo	hnth-branch-96	192.168.1.100	online	241	75	0	2026-10-21 08:22:20.876+07	2026-10-21 08:22:20.88197+07
408	agent-demo	hnth-branch-86	192.168.1.99	online	227	75	0	2026-10-21 08:22:24.377+07	2026-10-21 08:22:24.381893+07
409	agent-demo	hnth-branch-94	192.168.1.98	online	216	75	0	2026-10-21 08:22:24.378+07	2026-10-21 08:22:24.384196+07
410	agent-demo	hnth-branch-91	192.168.1.97	online	241	75	0	2026-10-21 08:22:27.866+07	2026-10-21 08:22:27.870843+07
411	agent-demo	hnth-branch-11	192.168.1.96	online	231	75	0	2026-10-21 08:22:27.866+07	2026-10-21 08:22:27.873055+07
412	agent-demo	hnth-branch-85	192.168.1.95	online	226	75	0	2026-10-21 08:22:31.381+07	2026-10-21 08:22:31.385464+07
413	agent-demo	hnth-branch-41	192.168.1.94	online	216	75	0	2026-10-21 08:22:31.381+07	2026-10-21 08:22:31.386683+07
414	agent-demo	hnth-branch-17	192.168.1.93	online	228	75	0	2026-10-21 08:22:34.878+07	2026-10-21 08:22:34.882707+07
415	agent-demo	hnth-branch-6	192.168.1.92	online	240	75	0	2026-10-21 08:22:34.878+07	2026-10-21 08:22:34.884246+07
416	agent-demo	hnth-branch-15	192.168.1.91	online	230	75	0	2026-10-21 08:22:38.378+07	2026-10-21 08:22:38.382203+07
417	agent-demo	hnth-branch-49	192.168.1.90	online	241	75	0	2026-10-21 08:22:38.378+07	2026-10-21 08:22:38.383656+07
418	agent-demo	hnth-branch-104	192.168.1.89	online	225	75	0	2026-10-21 08:22:41.88+07	2026-10-21 08:22:41.884487+07
419	agent-demo	hnth-branch-16	192.168.1.87	online	216	75	0	2026-10-21 08:22:41.88+07	2026-10-21 08:22:41.885738+07
420	agent-demo	hnth-branch-60	192.168.1.86	online	230	75	0	2026-10-21 08:22:45.372+07	2026-10-21 08:22:45.381073+07
421	agent-demo	hnth-branch-48	192.168.1.85	online	240	75	0	2026-10-21 08:22:45.373+07	2026-10-21 08:22:45.383443+07
422	agent-demo	hnth-branch-10	192.168.1.84	online	225	75	0	2026-10-21 08:22:48.882+07	2026-10-21 08:22:48.887202+07
423	agent-demo	hnth-branch-72	192.168.1.83	online	239	75	0	2026-10-21 08:22:48.88+07	2026-10-21 08:22:48.889272+07
424	agent-demo	hnth-branch-74	192.168.1.82	online	236	75	0	2026-10-21 08:22:52.375+07	2026-10-21 08:22:52.379726+07
425	agent-demo	hnth-branch-9	192.168.1.81	online	224	75	0	2026-10-21 08:22:52.374+07	2026-10-21 08:22:52.381355+07
426	agent-demo	hnth-branch-8	192.168.1.80	online	242	75	0	2026-10-21 08:22:55.871+07	2026-10-21 08:22:55.876189+07
427	agent-demo	hnth-branch-103	192.168.1.79	online	232	75	0	2026-10-21 08:22:55.872+07	2026-10-21 08:22:55.8775+07
428	agent-demo	hnth-branch-52	192.168.1.78	online	224	75	0	2026-10-21 08:22:59.378+07	2026-10-21 08:22:59.383272+07
429	agent-demo	hnth-branch-44	192.168.1.77	online	214	75	0	2026-10-21 08:22:59.379+07	2026-10-21 08:22:59.385152+07
430	agent-demo	hnth-branch-95	192.168.1.76	online	229	75	0	2026-10-21 08:23:02.868+07	2026-10-21 08:23:02.872645+07
431	agent-demo	hnth-branch-12	192.168.1.75	online	240	75	0	2026-10-21 08:23:02.868+07	2026-10-21 08:23:02.874003+07
432	agent-demo	hnth-branch-54	192.168.1.74	online	226	75	0	2026-10-21 08:23:06.378+07	2026-10-21 08:23:06.382319+07
433	agent-demo	hnth-branch-5	192.168.1.73	online	215	75	0	2026-10-21 08:23:06.378+07	2026-10-21 08:23:06.383673+07
434	agent-demo	hnth-branch-114	192.168.1.72	online	243	75	0	2026-10-21 08:23:09.884+07	2026-10-21 08:23:09.89093+07
435	agent-demo	hnth-branch-19	192.168.1.71	online	229	75	0	2026-10-21 08:23:09.886+07	2026-10-21 08:23:09.892869+07
436	agent-demo	hnth-branch-61	192.168.1.70	online	225	75	0	2026-10-21 08:23:13.373+07	2026-10-21 08:23:13.380765+07
437	agent-demo	hnth-branch-90	192.168.1.69	online	236	75	0	2026-10-21 08:23:13.373+07	2026-10-21 08:23:13.382783+07
438	agent-demo	hnth-branch-73	192.168.1.68	online	215	75	0	2026-10-21 08:23:16.875+07	2026-10-21 08:23:16.880086+07
439	agent-demo	hnth-branch-67	192.168.1.67	online	225	75	0	2026-10-21 08:23:16.875+07	2026-10-21 08:23:16.882331+07
440	agent-demo	hnth-branch-76	192.168.1.66	online	241	75	0	2026-10-21 08:23:20.367+07	2026-10-21 08:23:20.371614+07
441	agent-demo	hnth-branch-50	192.168.1.65	online	251	75	0	2026-10-21 08:23:20.367+07	2026-10-21 08:23:20.373625+07
442	agent-demo	hnth-hub	192.168.1.169	offline	223	75	0	2026-10-21 08:25:34.867+07	2026-10-21 08:25:34.874582+07
443	agent-demo	hnth-branch-110	192.168.1.159	offline	215	75	0	2026-10-21 08:25:34.867+07	2026-10-21 08:25:34.876463+07
444	agent-demo	hnth-branch-13	192.168.1.158	offline	229	75	0	2026-10-21 08:25:38.37+07	2026-10-21 08:25:38.376428+07
445	agent-demo	hnth-branch-20	192.168.1.157	offline	238	75	0	2026-10-21 08:25:38.369+07	2026-10-21 08:25:38.378173+07
446	agent-demo	hnth-branch-2	192.168.1.156	offline	228	75	0	2026-10-21 08:25:41.881+07	2026-10-21 08:25:41.884722+07
447	agent-demo	hnth-branch-38	192.168.1.155	offline	239	75	0	2026-10-21 08:25:41.881+07	2026-10-21 08:25:41.887609+07
448	agent-demo	hnth-branch-35	192.168.1.161	offline	253	75	0	2026-10-21 08:25:45.376+07	2026-10-21 08:25:45.380091+07
449	agent-demo	hnth-branch-33	192.168.1.126	offline	243	75	0	2026-10-21 08:25:45.376+07	2026-10-21 08:25:45.381514+07
450	agent-demo	hnth-branch-31	192.168.1.125	offline	233	75	0	2026-10-21 08:25:48.88+07	2026-10-21 08:25:48.884364+07
451	agent-demo	hnth-branch-89	192.168.1.124	offline	225	75	0	2026-10-21 08:25:48.88+07	2026-10-21 08:25:48.886561+07
452	agent-demo	hnth-branch-34	192.168.1.123	offline	236	75	0	2026-10-21 08:25:52.37+07	2026-10-21 08:25:52.374115+07
453	agent-demo	hnth-branch-93	192.168.1.122	offline	228	75	0	2026-10-21 08:25:52.37+07	2026-10-21 08:25:52.375248+07
454	agent-demo	hnth-branch-32	192.168.1.121	offline	226	75	0	2026-10-21 08:25:55.867+07	2026-10-21 08:25:55.871443+07
455	agent-demo	hnth-branch-18	192.168.1.120	offline	235	75	0	2026-10-21 08:25:55.867+07	2026-10-21 08:25:55.873015+07
456	agent-demo	hnth-branch-1	192.168.1.160	online	54	0	9.67	2026-10-21 08:25:56.866+07	2026-10-21 08:25:59.374077+07
457	agent-demo	hnth-branch-108	192.168.1.118	offline	235	75	0	2026-10-21 08:25:59.369+07	2026-10-21 08:25:59.375984+07
458	agent-demo	hnth-branch-42	192.168.1.117	offline	236	75	0	2026-10-21 08:26:02.875+07	2026-10-21 08:26:02.879099+07
459	agent-demo	hnth-branch-62	192.168.1.116	offline	227	75	0	2026-10-21 08:26:02.875+07	2026-10-21 08:26:02.881071+07
460	agent-demo	hnth-branch-69	192.168.1.1	online	45	0	2.67	2026-10-21 08:26:03.834+07	2026-10-21 08:26:06.373604+07
461	agent-demo	hnth-branch-59	192.168.1.114	offline	237	75	0	2026-10-21 08:26:06.369+07	2026-10-21 08:26:06.375197+07
462	agent-demo	hnth-branch-64	192.168.1.113	offline	239	75	0	2026-10-21 08:26:09.868+07	2026-10-21 08:26:09.872262+07
463	agent-demo	hnth-branch-27	192.168.1.112	offline	230	75	0	2026-10-21 08:26:09.868+07	2026-10-21 08:26:09.873594+07
464	agent-demo	hnth-branch-107	192.168.1.111	offline	236	75	0	2026-10-21 08:26:13.366+07	2026-10-21 08:26:13.373794+07
465	agent-demo	hnth-branch-97	192.168.1.110	offline	228	75	0	2026-10-21 08:26:13.366+07	2026-10-21 08:26:13.37581+07
466	agent-demo	hnth-branch-106	192.168.1.109	offline	226	75	0	2026-10-21 08:26:16.874+07	2026-10-21 08:26:16.877413+07
467	agent-demo	hnth-branch-75	192.168.1.108	offline	235	75	0	2026-10-21 08:26:16.874+07	2026-10-21 08:26:16.878838+07
468	agent-demo	hnth-branch-92	192.168.1.107	offline	203	75	0	2026-10-21 08:26:20.374+07	2026-10-21 08:26:20.378556+07
469	agent-demo	hnth-branch-70	192.168.1.106	offline	236	75	0	2026-10-21 08:26:20.374+07	2026-10-21 08:26:20.380214+07
470	agent-demo	hnth-branch-83	192.168.1.105	offline	229	75	0	2026-10-21 08:26:23.878+07	2026-10-21 08:26:23.88197+07
471	agent-demo	hnth-branch-63	192.168.1.104	offline	238	75	0	2026-10-21 08:26:23.879+07	2026-10-21 08:26:23.883451+07
472	agent-demo	hnth-branch-68	192.168.1.103	offline	238	75	0	2026-10-21 08:26:27.365+07	2026-10-21 08:26:27.370296+07
473	agent-demo	hnth-branch-78	192.168.1.102	offline	226	75	0	2026-10-21 08:26:27.365+07	2026-10-21 08:26:27.372318+07
474	agent-demo	hnth-branch-14	192.168.1.101	offline	239	75	0	2026-10-21 08:26:30.87+07	2026-10-21 08:26:30.874343+07
475	agent-demo	hnth-branch-96	192.168.1.100	offline	230	75	0	2026-10-21 08:26:30.87+07	2026-10-21 08:26:30.875898+07
476	agent-demo	hnth-branch-86	192.168.1.99	offline	236	75	0	2026-10-21 08:26:34.38+07	2026-10-21 08:26:34.38453+07
477	agent-demo	hnth-branch-94	192.168.1.98	offline	229	75	0	2026-10-21 08:26:34.38+07	2026-10-21 08:26:34.387214+07
478	agent-demo	hnth-branch-91	192.168.1.97	offline	257	75	0	2026-10-21 08:26:37.873+07	2026-10-21 08:26:37.876234+07
479	agent-demo	hnth-branch-11	192.168.1.96	offline	232	75	0	2026-10-21 08:26:37.873+07	2026-10-21 08:26:37.877654+07
480	agent-demo	hnth-branch-85	192.168.1.95	offline	226	75	0	2026-10-21 08:26:41.38+07	2026-10-21 08:26:41.383784+07
481	agent-demo	hnth-branch-41	192.168.1.94	offline	235	75	0	2026-10-21 08:26:41.379+07	2026-10-21 08:26:41.385304+07
482	agent-demo	hnth-branch-17	192.168.1.93	offline	230	75	0	2026-10-21 08:26:44.866+07	2026-10-21 08:26:44.872388+07
483	agent-demo	hnth-branch-6	192.168.1.92	offline	241	75	0	2026-10-21 08:26:44.866+07	2026-10-21 08:26:44.883552+07
484	agent-demo	hnth-branch-15	192.168.1.91	offline	224	75	0	2026-10-21 08:26:48.373+07	2026-10-21 08:26:48.378983+07
485	agent-demo	hnth-branch-49	192.168.1.90	offline	217	75	0	2026-10-21 08:26:48.373+07	2026-10-21 08:26:48.380407+07
486	agent-demo	hnth-branch-104	192.168.1.89	offline	225	75	0	2026-10-21 08:26:51.876+07	2026-10-21 08:26:51.879714+07
487	agent-demo	hnth-branch-16	192.168.1.87	offline	216	75	0	2026-10-21 08:26:51.876+07	2026-10-21 08:26:51.881593+07
488	agent-demo	hnth-branch-60	192.168.1.86	offline	246	75	0	2026-10-21 08:26:55.371+07	2026-10-21 08:26:55.375645+07
489	agent-demo	hnth-branch-48	192.168.1.85	offline	255	75	0	2026-10-21 08:26:55.371+07	2026-10-21 08:26:55.377338+07
490	agent-demo	hnth-branch-10	192.168.1.84	offline	214	75	0	2026-10-21 08:26:58.867+07	2026-10-21 08:26:58.872252+07
491	agent-demo	hnth-branch-72	192.168.1.83	offline	223	75	0	2026-10-21 08:26:58.867+07	2026-10-21 08:26:58.874076+07
492	agent-demo	hnth-branch-74	192.168.1.82	offline	230	75	0	2026-10-21 08:27:02.379+07	2026-10-21 08:27:02.3827+07
493	agent-demo	hnth-branch-9	192.168.1.81	offline	238	75	0	2026-10-21 08:27:02.379+07	2026-10-21 08:27:02.384771+07
494	agent-demo	hnth-branch-8	192.168.1.80	offline	238	75	0	2026-10-21 08:27:05.876+07	2026-10-21 08:27:05.87914+07
495	agent-demo	hnth-branch-103	192.168.1.79	offline	228	75	0	2026-10-21 08:27:05.876+07	2026-10-21 08:27:05.880449+07
496	agent-demo	hnth-branch-52	192.168.1.78	offline	237	75	0	2026-10-21 08:27:09.375+07	2026-10-21 08:27:09.37887+07
497	agent-demo	hnth-branch-44	192.168.1.77	offline	210	75	0	2026-10-21 08:27:09.375+07	2026-10-21 08:27:09.380335+07
498	agent-demo	hnth-branch-95	192.168.1.76	offline	240	75	0	2026-10-21 08:27:12.867+07	2026-10-21 08:27:12.870011+07
499	agent-demo	hnth-branch-12	192.168.1.75	offline	229	75	0	2026-10-21 08:27:12.867+07	2026-10-21 08:27:12.871312+07
500	agent-demo	hnth-branch-54	192.168.1.74	offline	197	75	0	2026-10-21 08:27:16.38+07	2026-10-21 08:27:16.384411+07
501	agent-demo	hnth-branch-5	192.168.1.73	offline	226	75	0	2026-10-21 08:27:16.38+07	2026-10-21 08:27:16.385863+07
502	agent-demo	hnth-branch-114	192.168.1.72	offline	241	75	0	2026-10-21 08:27:19.875+07	2026-10-21 08:27:19.879362+07
503	agent-demo	hnth-branch-19	192.168.1.71	offline	233	75	0	2026-10-21 08:27:19.875+07	2026-10-21 08:27:19.880791+07
504	agent-demo	hnth-branch-61	192.168.1.70	offline	233	75	0	2026-10-21 08:27:23.375+07	2026-10-21 08:27:23.382188+07
505	agent-demo	hnth-branch-90	192.168.1.69	offline	240	75	0	2026-10-21 08:27:23.375+07	2026-10-21 08:27:23.384091+07
506	agent-demo	hnth-branch-73	192.168.1.68	offline	235	75	0	2026-10-21 08:27:26.872+07	2026-10-21 08:27:26.876146+07
507	agent-demo	hnth-branch-67	192.168.1.67	offline	243	75	0	2026-10-21 08:27:26.872+07	2026-10-21 08:27:26.877533+07
508	agent-demo	hnth-branch-76	192.168.1.66	offline	231	75	0	2026-10-21 08:27:30.38+07	2026-10-21 08:27:30.3843+07
509	agent-demo	hnth-branch-50	192.168.1.65	offline	240	75	0	2026-10-21 08:27:30.38+07	2026-10-21 08:27:30.385706+07
510	agent-demo	hnth-branch-81	192.168.1.64	offline	238	75	0	2026-10-21 08:27:33.872+07	2026-10-21 08:27:33.87647+07
511	agent-demo	hnth-branch-39	192.168.1.63	offline	230	75	0	2026-10-21 08:27:33.872+07	2026-10-21 08:27:33.877886+07
514	agent-demo	hnth-branch-53	192.168.1.60	offline	239	75	0	2026-10-21 08:27:40.877+07	2026-10-21 08:27:40.881328+07
515	agent-demo	hnth-branch-43	192.168.1.59	offline	231	75	0	2026-10-21 08:27:40.878+07	2026-10-21 08:27:40.882882+07
516	agent-demo	hnth-branch-100	192.168.1.58	offline	240	75	0	2026-10-21 08:27:44.367+07	2026-10-21 08:27:44.378498+07
517	agent-demo	hnth-branch-57	192.168.1.57	offline	233	75	0	2026-10-21 08:27:44.367+07	2026-10-21 08:27:44.379994+07
520	agent-demo	hnth-branch-55	192.168.1.54	offline	229	75	0	2026-10-21 08:27:51.379+07	2026-10-21 08:27:51.383212+07
521	agent-demo	hnth-branch-3	192.168.1.53	offline	237	75	0	2026-10-21 08:27:51.379+07	2026-10-21 08:27:51.384644+07
524	agent-demo	hnth-branch-47	192.168.1.50	online	52	0	6	2026-10-21 08:27:55.861+07	2026-10-21 08:27:55.869844+07
525	agent-demo	hnth-branch-77	192.168.1.49	online	49	0	2.67	2026-10-21 08:27:55.865+07	2026-10-21 08:27:55.871144+07
530	agent-demo	hnth-branch-113	192.168.1.44	offline	217	75	0	2026-10-21 08:28:06.371+07	2026-10-21 08:28:06.375445+07
531	agent-demo	hnth-branch-88	192.168.1.43	offline	226	75	0	2026-10-21 08:28:06.371+07	2026-10-21 08:28:06.376737+07
534	agent-demo	hnth-branch-82	192.168.1.40	offline	238	75	0	2026-10-21 08:28:13.371+07	2026-10-21 08:28:13.375123+07
535	agent-demo	hnth-branch-51	192.168.1.39	offline	229	75	0	2026-10-21 08:28:13.371+07	2026-10-21 08:28:13.376651+07
536	agent-demo	hnth-branch-24	192.168.1.38	offline	241	75	0	2026-10-21 08:28:16.872+07	2026-10-21 08:28:16.876395+07
537	agent-demo	hnth-branch-25	192.168.1.37	offline	231	75	0	2026-10-21 08:28:16.872+07	2026-10-21 08:28:16.877967+07
540	agent-demo	hnth-branch-58	192.168.1.14	offline	241	75	0	2026-10-21 08:28:23.882+07	2026-10-21 08:28:23.886629+07
541	agent-demo	hnth-branch-105	192.168.1.13	offline	232	75	0	2026-10-21 08:28:23.88+07	2026-10-21 08:28:23.888491+07
544	agent-demo	hnth-branch-98	192.168.1.10	offline	239	75	0	2026-10-21 08:28:31.379+07	2026-10-21 08:28:31.383028+07
545	agent-demo	hnth-branch-66	192.168.1.9	offline	231	75	0	2026-10-21 08:28:31.379+07	2026-10-21 08:28:31.384801+07
548	agent-demo	hnth-branch-30	192.168.1.6	online	45	0	3.33	2026-10-21 08:28:36.328+07	2026-10-21 08:28:36.363686+07
549	agent-demo	hnth-branch-21	192.168.1.5	online	52	0	10	2026-10-21 08:28:36.359+07	2026-10-21 08:28:36.365575+07
552	agent-demo	hnth-branch-46	192.168.1.2	online	43	0	6.67	2026-10-21 08:28:40.829+07	2026-10-21 08:28:43.381773+07
553	agent-demo	hnth-branch-22	192.168.1.135	offline	241	75	0	2026-10-21 08:28:43.377+07	2026-10-21 08:28:43.383353+07
554	agent-demo	hnth-branch-37	192.168.1.0	offline	211	75	0	2026-10-21 08:28:46.88+07	2026-10-21 08:28:46.884577+07
555	agent-demo	hnth-branch-40	192.168.1.16	offline	239	75	0	2026-10-21 08:28:46.88+07	2026-10-21 08:28:46.885872+07
1305	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	218	75	0	2026-10-21 17:58:45.383+07	2026-10-21 17:58:45.392407+07
1306	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	226	75	0	2026-10-21 17:58:45.383+07	2026-10-21 17:58:45.413641+07
1309	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	265	75	0	2026-10-21 17:58:52.877+07	2026-10-21 17:58:52.883843+07
1310	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	230	75	0	2026-10-21 17:58:52.877+07	2026-10-21 17:58:52.886133+07
1311	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	232	75	0	2026-10-21 17:58:56.373+07	2026-10-21 17:58:56.37844+07
1312	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	244	75	0	2026-10-21 17:58:56.373+07	2026-10-21 17:58:56.380828+07
1315	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	241	75	0	2026-10-21 17:59:03.379+07	2026-10-21 17:59:03.383854+07
1316	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	229	75	0	2026-10-21 17:59:03.379+07	2026-10-21 17:59:03.387509+07
1323	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	56	0	10.33	2026-10-21 17:59:14.881+07	2026-10-21 17:59:17.372437+07
1324	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	236	75	0	2026-10-21 17:59:17.367+07	2026-10-21 17:59:17.374053+07
1329	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	239	75	0	2026-10-21 17:59:27.873+07	2026-10-21 17:59:27.876885+07
1330	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	228	75	0	2026-10-21 17:59:27.873+07	2026-10-21 17:59:27.878138+07
1333	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	229	75	0	2026-10-21 17:59:34.872+07	2026-10-21 17:59:34.877149+07
1334	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	237	75	0	2026-10-21 17:59:34.872+07	2026-10-21 17:59:34.878918+07
1337	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	217	75	0	2026-10-21 17:59:41.873+07	2026-10-21 17:59:41.877758+07
1338	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	226	75	0	2026-10-21 17:59:41.873+07	2026-10-21 17:59:41.879181+07
1341	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	231	75	0	2026-10-21 17:59:48.88+07	2026-10-21 17:59:48.884718+07
1342	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	239	75	0	2026-10-21 17:59:48.88+07	2026-10-21 17:59:48.886289+07
1345	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	233	75	0	2026-10-21 17:59:55.887+07	2026-10-21 17:59:55.906637+07
1346	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	241	75	0	2026-10-21 17:59:55.887+07	2026-10-21 17:59:55.911952+07
1347	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	239	75	0	2026-10-21 17:59:59.373+07	2026-10-21 17:59:59.37759+07
1348	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	226	75	0	2026-10-21 17:59:59.372+07	2026-10-21 17:59:59.379592+07
1349	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	231	75	0	2026-10-21 18:00:02.873+07	2026-10-21 18:00:02.877127+07
1350	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	240	75	0	2026-10-21 18:00:02.873+07	2026-10-21 18:00:02.878545+07
1355	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	239	75	0	2026-10-21 18:00:13.376+07	2026-10-21 18:00:13.380924+07
1356	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	229	75	0	2026-10-21 18:00:13.376+07	2026-10-21 18:00:13.382297+07
1359	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	254	75	0	2026-10-21 18:00:20.379+07	2026-10-21 18:00:20.383321+07
1360	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	245	75	0	2026-10-21 18:00:20.379+07	2026-10-21 18:00:20.384624+07
1361	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	209	75	0	2026-10-21 18:00:23.876+07	2026-10-21 18:00:23.880163+07
1362	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	235	75	0	2026-10-21 18:00:23.876+07	2026-10-21 18:00:23.881481+07
1363	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	236	75	0	2026-10-21 18:00:27.366+07	2026-10-21 18:00:27.370166+07
1364	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	228	75	0	2026-10-21 18:00:27.366+07	2026-10-21 18:00:27.371376+07
1367	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	231	75	0	2026-10-21 18:00:34.381+07	2026-10-21 18:00:34.385242+07
1368	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	239	75	0	2026-10-21 18:00:34.381+07	2026-10-21 18:00:34.386447+07
1369	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	231	75	0	2026-10-21 18:00:37.87+07	2026-10-21 18:00:37.873916+07
1370	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	239	75	0	2026-10-21 18:00:37.87+07	2026-10-21 18:00:37.875123+07
1373	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	246	75	0	2026-10-21 18:00:44.866+07	2026-10-21 18:00:44.870432+07
1374	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	255	75	0	2026-10-21 18:00:44.866+07	2026-10-21 18:00:44.87165+07
512	agent-demo	hnth-branch-84	192.168.1.62	offline	233	75	0	2026-10-21 08:27:37.375+07	2026-10-21 08:27:37.379226+07
513	agent-demo	hnth-branch-29	192.168.1.61	offline	241	75	0	2026-10-21 08:27:37.375+07	2026-10-21 08:27:37.380918+07
518	agent-demo	hnth-branch-109	192.168.1.56	offline	225	75	0	2026-10-21 08:27:47.87+07	2026-10-21 08:27:47.873888+07
519	agent-demo	hnth-branch-45	192.168.1.55	offline	216	75	0	2026-10-21 08:27:47.87+07	2026-10-21 08:27:47.875737+07
522	agent-demo	hnth-branch-111	192.168.1.52	online	44	0	3.33	2026-10-21 08:27:52.332+07	2026-10-21 08:27:54.884743+07
523	agent-demo	hnth-branch-36	192.168.1.51	offline	255	75	0	2026-10-21 08:27:54.881+07	2026-10-21 08:27:54.885983+07
526	agent-demo	hnth-branch-99	192.168.1.48	offline	226	75	0	2026-10-21 08:27:59.374+07	2026-10-21 08:27:59.378869+07
527	agent-demo	hnth-branch-26	192.168.1.47	offline	237	75	0	2026-10-21 08:27:59.374+07	2026-10-21 08:27:59.380464+07
528	agent-demo	hnth-branch-112	192.168.1.46	offline	229	75	0	2026-10-21 08:28:02.867+07	2026-10-21 08:28:02.873172+07
529	agent-demo	hnth-branch-65	192.168.1.45	offline	238	75	0	2026-10-21 08:28:02.867+07	2026-10-21 08:28:02.875046+07
532	agent-demo	hnth-branch-102	192.168.1.42	offline	246	75	0	2026-10-21 08:28:09.879+07	2026-10-21 08:28:09.882976+07
533	agent-demo	hnth-branch-7	192.168.1.41	offline	255	75	0	2026-10-21 08:28:09.879+07	2026-10-21 08:28:09.884416+07
538	agent-demo	hnth-branch-56	192.168.1.36	offline	240	75	0	2026-10-21 08:28:20.379+07	2026-10-21 08:28:20.38373+07
539	agent-demo	hnth-branch-87	192.168.1.15	offline	232	75	0	2026-10-21 08:28:20.379+07	2026-10-21 08:28:20.385836+07
542	agent-demo	hnth-branch-101	192.168.1.12	offline	239	75	0	2026-10-21 08:28:27.369+07	2026-10-21 08:28:27.87442+07
543	agent-demo	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 08:28:27.87+07	2026-10-21 08:28:27.875932+07
546	agent-demo	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 08:28:35.366+07	2026-10-21 08:28:35.370923+07
547	agent-demo	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 08:28:35.366+07	2026-10-21 08:28:35.372293+07
550	agent-demo	hnth-branch-28	192.168.1.4	online	43	0	5.33	2026-10-21 08:28:37.315+07	2026-10-21 08:28:39.877945+07
551	agent-demo	hnth-branch-23	192.168.1.3	offline	237	75	0	2026-10-21 08:28:39.874+07	2026-10-21 08:28:39.879632+07
556	agent-demo	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 08:32:00.366+07	2026-10-21 08:32:00.372901+07
557	agent-demo	hnth-hub	192.168.1.169	offline	243	75	0	2026-10-21 08:35:09.381+07	2026-10-21 08:35:09.387021+07
558	agent-demo	hnth-hub	192.168.1.169	offline	232	75	0	2026-10-21 08:38:18.368+07	2026-10-21 08:38:18.374176+07
559	agent-demo	hnth-hub	192.168.1.169	offline	254	75	0	2026-10-21 08:41:28.866+07	2026-10-21 08:41:28.87322+07
560	agent-demo	hnth-hub	192.168.1.169	offline	249	75	0	2026-10-21 08:44:39.867+07	2026-10-21 08:44:39.875277+07
561	agent-demo	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 08:47:49.366+07	2026-10-21 08:47:49.372508+07
562	agent-demo	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-21 08:50:58.38+07	2026-10-21 08:50:58.384223+07
563	agent-demo	hnth-hub	192.168.1.169	offline	256	75	0	2026-10-21 08:54:07.374+07	2026-10-21 08:54:07.380138+07
564	agent-demo	hnth-hub	192.168.1.169	offline	233	75	0	2026-10-21 10:02:12.882+07	2026-10-21 10:02:12.89027+07
565	agent-demo	hnth-branch-110	192.168.1.159	offline	238	75	0	2026-10-21 10:02:12.882+07	2026-10-21 10:02:12.904472+07
566	agent-demo	hnth-branch-13	192.168.1.158	offline	248	75	0	2026-10-21 10:02:16.368+07	2026-10-21 10:02:16.373585+07
567	agent-demo	hnth-branch-20	192.168.1.157	offline	253	75	0	2026-10-21 10:02:16.368+07	2026-10-21 10:02:16.375597+07
568	agent-demo	hnth-branch-2	192.168.1.156	offline	236	75	0	2026-10-21 10:02:19.875+07	2026-10-21 10:02:19.878237+07
569	agent-demo	hnth-branch-38	192.168.1.155	offline	239	75	0	2026-10-21 10:02:19.875+07	2026-10-21 10:02:19.880103+07
570	agent-demo	hnth-branch-35	192.168.1.161	offline	252	75	0	2026-10-21 10:02:23.368+07	2026-10-21 10:02:23.371401+07
571	agent-demo	hnth-branch-33	192.168.1.126	offline	254	75	0	2026-10-21 10:02:23.368+07	2026-10-21 10:02:23.373139+07
572	agent-demo	hnth-branch-31	192.168.1.125	offline	232	75	0	2026-10-21 10:02:26.877+07	2026-10-21 10:02:26.88068+07
573	agent-demo	hnth-branch-89	192.168.1.124	offline	236	75	0	2026-10-21 10:02:26.877+07	2026-10-21 10:02:26.883282+07
574	agent-demo	hnth-branch-34	192.168.1.123	offline	240	75	0	2026-10-21 10:02:30.368+07	2026-10-21 10:02:30.371767+07
575	agent-demo	hnth-branch-93	192.168.1.122	offline	236	75	0	2026-10-21 10:02:30.368+07	2026-10-21 10:02:30.37318+07
576	agent-demo	hnth-branch-32	192.168.1.121	offline	239	75	0	2026-10-21 10:02:33.882+07	2026-10-21 10:02:33.885865+07
577	agent-demo	hnth-branch-18	192.168.1.120	offline	234	75	0	2026-10-21 10:02:33.881+07	2026-10-21 10:02:33.887257+07
578	agent-demo	hnth-branch-1	192.168.1.160	online	37	0	4	2026-10-21 10:02:34.81+07	2026-10-21 10:02:37.374324+07
579	agent-demo	hnth-branch-108	192.168.1.118	offline	223	75	0	2026-10-21 10:02:37.371+07	2026-10-21 10:02:37.376186+07
580	agent-demo	hnth-branch-42	192.168.1.117	offline	240	75	0	2026-10-21 10:02:40.876+07	2026-10-21 10:02:40.880624+07
581	agent-demo	hnth-branch-62	192.168.1.116	offline	236	75	0	2026-10-21 10:02:40.877+07	2026-10-21 10:02:40.88325+07
582	agent-demo	hnth-branch-69	192.168.1.1	online	40	0	3.33	2026-10-21 10:02:41.821+07	2026-10-21 10:02:44.380693+07
583	agent-demo	hnth-branch-59	192.168.1.114	offline	223	75	0	2026-10-21 10:02:44.373+07	2026-10-21 10:02:44.383927+07
584	agent-demo	hnth-branch-64	192.168.1.113	offline	230	75	0	2026-10-21 10:02:47.882+07	2026-10-21 10:02:47.886656+07
585	agent-demo	hnth-branch-27	192.168.1.112	offline	235	75	0	2026-10-21 10:02:47.882+07	2026-10-21 10:02:47.887939+07
586	agent-demo	hnth-branch-107	192.168.1.111	offline	237	75	0	2026-10-21 10:02:51.376+07	2026-10-21 10:02:51.379862+07
587	agent-demo	hnth-branch-97	192.168.1.110	offline	240	75	0	2026-10-21 10:02:51.376+07	2026-10-21 10:02:51.382558+07
588	agent-demo	hnth-branch-106	192.168.1.109	offline	253	75	0	2026-10-21 10:02:54.877+07	2026-10-21 10:02:54.880771+07
589	agent-demo	hnth-branch-75	192.168.1.108	offline	249	75	0	2026-10-21 10:02:54.877+07	2026-10-21 10:02:54.883611+07
590	agent-demo	hnth-branch-92	192.168.1.107	offline	253	75	0	2026-10-21 10:02:58.376+07	2026-10-21 10:02:58.380631+07
591	agent-demo	hnth-branch-70	192.168.1.106	offline	249	75	0	2026-10-21 10:02:58.376+07	2026-10-21 10:02:58.382935+07
592	agent-demo	hnth-branch-83	192.168.1.105	offline	236	75	0	2026-10-21 10:03:01.876+07	2026-10-21 10:03:01.879597+07
593	agent-demo	hnth-branch-63	192.168.1.104	offline	242	75	0	2026-10-21 10:03:01.876+07	2026-10-21 10:03:01.881819+07
594	agent-demo	hnth-branch-68	192.168.1.103	offline	254	75	0	2026-10-21 10:03:05.374+07	2026-10-21 10:03:05.378072+07
595	agent-demo	hnth-branch-78	192.168.1.102	offline	250	75	0	2026-10-21 10:03:05.375+07	2026-10-21 10:03:05.379849+07
596	agent-demo	hnth-branch-14	192.168.1.101	offline	239	75	0	2026-10-21 10:03:08.878+07	2026-10-21 10:03:08.882058+07
597	agent-demo	hnth-branch-96	192.168.1.100	offline	235	75	0	2026-10-21 10:03:08.878+07	2026-10-21 10:03:08.883931+07
598	agent-demo	hnth-branch-86	192.168.1.99	offline	234	75	0	2026-10-21 10:03:12.378+07	2026-10-21 10:03:12.382501+07
599	agent-demo	hnth-branch-94	192.168.1.98	offline	238	75	0	2026-10-21 10:03:12.377+07	2026-10-21 10:03:12.384081+07
600	agent-demo	hnth-branch-91	192.168.1.97	offline	239	75	0	2026-10-21 10:03:15.872+07	2026-10-21 10:03:15.875816+07
601	agent-demo	hnth-branch-11	192.168.1.96	offline	235	75	0	2026-10-21 10:03:15.872+07	2026-10-21 10:03:15.877316+07
602	agent-demo	hnth-branch-85	192.168.1.95	offline	240	75	0	2026-10-21 10:03:19.383+07	2026-10-21 10:03:19.387498+07
603	agent-demo	hnth-branch-41	192.168.1.94	offline	235	75	0	2026-10-21 10:03:19.383+07	2026-10-21 10:03:19.389287+07
604	agent-demo	hnth-branch-17	192.168.1.93	offline	236	75	0	2026-10-21 10:03:22.867+07	2026-10-21 10:03:22.871456+07
605	agent-demo	hnth-branch-6	192.168.1.92	offline	232	75	0	2026-10-21 10:03:22.867+07	2026-10-21 10:03:22.872968+07
606	agent-demo	hnth-branch-15	192.168.1.91	offline	238	75	0	2026-10-21 10:03:26.368+07	2026-10-21 10:03:26.371964+07
607	agent-demo	hnth-branch-49	192.168.1.90	offline	231	75	0	2026-10-21 10:03:26.368+07	2026-10-21 10:03:26.373783+07
608	agent-demo	hnth-branch-104	192.168.1.89	offline	251	75	0	2026-10-21 10:03:29.875+07	2026-10-21 10:03:29.88281+07
609	agent-demo	hnth-branch-16	192.168.1.87	offline	227	75	0	2026-10-21 10:03:29.878+07	2026-10-21 10:03:29.885237+07
610	agent-demo	hnth-branch-60	192.168.1.86	offline	242	75	0	2026-10-21 10:03:33.37+07	2026-10-21 10:03:33.373707+07
611	agent-demo	hnth-branch-48	192.168.1.85	offline	237	75	0	2026-10-21 10:03:33.37+07	2026-10-21 10:03:33.374785+07
612	agent-demo	hnth-branch-10	192.168.1.84	offline	236	75	0	2026-10-21 10:03:36.869+07	2026-10-21 10:03:36.87302+07
613	agent-demo	hnth-branch-72	192.168.1.83	offline	232	75	0	2026-10-21 10:03:36.869+07	2026-10-21 10:03:36.874458+07
1307	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	240	75	0	2026-10-21 17:58:48.892+07	2026-10-21 17:58:48.899679+07
1308	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	231	75	0	2026-10-21 17:58:48.878+07	2026-10-21 17:58:48.902712+07
1313	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	210	75	0	2026-10-21 17:58:59.87+07	2026-10-21 17:58:59.874576+07
1314	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	236	75	0	2026-10-21 17:58:59.87+07	2026-10-21 17:58:59.87632+07
1317	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	242	75	0	2026-10-21 17:59:06.881+07	2026-10-21 17:59:06.886347+07
1318	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	230	75	0	2026-10-21 17:59:06.881+07	2026-10-21 17:59:06.888696+07
1319	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	47	0	5.33	2026-10-21 17:59:07.862+07	2026-10-21 17:59:10.375824+07
1320	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	252	75	0	2026-10-21 17:59:10.367+07	2026-10-21 17:59:10.377824+07
1321	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	233	75	0	2026-10-21 17:59:13.872+07	2026-10-21 17:59:13.876702+07
1322	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	243	75	0	2026-10-21 17:59:13.872+07	2026-10-21 17:59:13.878498+07
1325	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	229	75	0	2026-10-21 17:59:20.872+07	2026-10-21 17:59:20.877829+07
1326	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	237	75	0	2026-10-21 17:59:20.872+07	2026-10-21 17:59:20.87922+07
1327	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	208	75	0	2026-10-21 17:59:24.381+07	2026-10-21 17:59:24.385546+07
1328	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	242	75	0	2026-10-21 17:59:24.381+07	2026-10-21 17:59:24.387947+07
1331	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	248	75	0	2026-10-21 17:59:31.369+07	2026-10-21 17:59:31.374426+07
1332	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	255	75	0	2026-10-21 17:59:31.368+07	2026-10-21 17:59:31.376282+07
1335	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	216	75	0	2026-10-21 17:59:38.376+07	2026-10-21 17:59:38.380752+07
1336	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	228	75	0	2026-10-21 17:59:38.376+07	2026-10-21 17:59:38.382635+07
1339	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	233	75	0	2026-10-21 17:59:45.372+07	2026-10-21 17:59:45.376431+07
1340	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	241	75	0	2026-10-21 17:59:45.372+07	2026-10-21 17:59:45.378051+07
1343	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	237	75	0	2026-10-21 17:59:52.368+07	2026-10-21 17:59:52.37208+07
1344	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	227	75	0	2026-10-21 17:59:52.367+07	2026-10-21 17:59:52.373828+07
1428	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	236	75	0	2026-10-21 18:27:16.872+07	2026-10-21 18:27:16.883437+07
1474	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	214	75	0	2026-10-21 18:43:59.375+07	2026-10-21 18:43:59.384041+07
1475	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	222	75	0	2026-10-21 18:43:59.375+07	2026-10-21 18:43:59.387657+07
1554	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	227	75	0	2026-10-21 19:01:42.383+07	2026-10-21 19:01:42.391317+07
1602	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	240	75	0	2026-10-21 19:18:15.376+07	2026-10-21 19:18:15.394015+07
1605	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	237	75	0	2026-10-21 19:18:22.371+07	2026-10-21 19:18:22.375405+07
1606	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	243	75	0	2026-10-21 19:18:22.371+07	2026-10-21 19:18:22.376816+07
1611	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	230	75	0	2026-10-21 19:18:32.878+07	2026-10-21 19:18:32.88302+07
1612	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	242	75	0	2026-10-21 19:18:32.878+07	2026-10-21 19:18:32.884831+07
1615	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	231	75	0	2026-10-21 19:18:39.88+07	2026-10-21 19:18:39.884047+07
1616	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	236	75	0	2026-10-21 19:18:39.88+07	2026-10-21 19:18:39.885639+07
1617	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	70	0	18	2026-10-21 19:18:40.958+07	2026-10-21 19:18:43.373537+07
1618	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	238	75	0	2026-10-21 19:18:43.369+07	2026-10-21 19:18:43.375567+07
1621	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	233	75	0	2026-10-21 19:18:50.373+07	2026-10-21 19:18:50.376925+07
1622	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	243	75	0	2026-10-21 19:18:50.373+07	2026-10-21 19:18:50.378321+07
1625	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	231	75	0	2026-10-21 19:18:57.37+07	2026-10-21 19:18:57.37621+07
1626	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	241	75	0	2026-10-21 19:18:57.37+07	2026-10-21 19:18:57.378514+07
1629	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	233	75	0	2026-10-21 19:19:04.379+07	2026-10-21 19:19:04.38222+07
1630	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	239	75	0	2026-10-21 19:19:04.379+07	2026-10-21 19:19:04.383566+07
1698	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	239	75	0	2026-10-21 19:21:00.877+07	2026-10-21 19:21:00.883228+07
1701	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	217	75	0	2026-10-21 19:21:08.37+07	2026-10-21 19:21:08.373634+07
1702	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	224	75	0	2026-10-21 19:21:08.37+07	2026-10-21 19:21:08.375038+07
1705	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	40	0	12.67	2026-10-21 19:21:13.334+07	2026-10-21 19:21:13.340123+07
1706	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	41	0	8	2026-10-21 19:21:13.336+07	2026-10-21 19:21:13.341437+07
1707	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	41	0	20.67	2026-10-21 19:21:14.29+07	2026-10-21 19:21:16.878754+07
1708	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	240	75	0	2026-10-21 19:21:16.875+07	2026-10-21 19:21:16.88017+07
1711	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	237	75	0	2026-10-21 19:21:23.875+07	2026-10-21 19:21:23.8791+07
1712	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	231	75	0	2026-10-21 19:21:23.875+07	2026-10-21 19:21:23.880443+07
1714	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 19:27:42.373+07	2026-10-21 19:27:42.385814+07
1717	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	unknown	244	50	313	2026-10-21 19:33:39.885+07	2026-10-21 19:33:40.391258+07
1718	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 19:33:55.867+07	2026-10-21 19:33:55.872125+07
1721	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 19:40:06.875+07	2026-10-21 19:40:06.882788+07
1722	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	234	75	0	2026-10-21 19:40:12.376+07	2026-10-21 19:40:12.38251+07
1727	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	173	0	38.67	2026-10-21 19:49:13.855+07	2026-10-21 19:49:15.885391+07
1730	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	203	75	0	2026-10-21 19:52:43.878+07	2026-10-21 19:52:43.884251+07
614	agent-demo	hnth-branch-74	192.168.1.82	offline	224	75	0	2026-10-21 10:03:40.377+07	2026-10-21 10:03:40.382667+07
615	agent-demo	hnth-branch-9	192.168.1.81	offline	219	75	0	2026-10-21 10:03:40.377+07	2026-10-21 10:03:40.384939+07
616	agent-demo	hnth-branch-8	192.168.1.80	offline	232	75	0	2026-10-21 10:03:43.872+07	2026-10-21 10:03:43.877641+07
617	agent-demo	hnth-branch-103	192.168.1.79	offline	236	75	0	2026-10-21 10:03:43.872+07	2026-10-21 10:03:43.881006+07
618	agent-demo	hnth-branch-52	192.168.1.78	offline	232	75	0	2026-10-21 10:03:47.375+07	2026-10-21 10:03:47.382438+07
619	agent-demo	hnth-branch-44	192.168.1.77	offline	237	75	0	2026-10-21 10:03:47.376+07	2026-10-21 10:03:47.384122+07
620	agent-demo	hnth-branch-95	192.168.1.76	offline	233	75	0	2026-10-21 10:03:50.868+07	2026-10-21 10:03:50.872533+07
621	agent-demo	hnth-branch-12	192.168.1.75	offline	238	75	0	2026-10-21 10:03:50.869+07	2026-10-21 10:03:50.873866+07
622	agent-demo	hnth-branch-54	192.168.1.74	offline	236	75	0	2026-10-21 10:03:54.381+07	2026-10-21 10:03:54.385397+07
623	agent-demo	hnth-branch-5	192.168.1.73	offline	231	75	0	2026-10-21 10:03:54.381+07	2026-10-21 10:03:54.38702+07
624	agent-demo	hnth-branch-114	192.168.1.72	offline	231	75	0	2026-10-21 10:03:57.874+07	2026-10-21 10:03:57.882913+07
625	agent-demo	hnth-branch-19	192.168.1.71	offline	236	75	0	2026-10-21 10:03:57.874+07	2026-10-21 10:03:57.884514+07
626	agent-demo	hnth-branch-61	192.168.1.70	offline	232	75	0	2026-10-21 10:04:01.381+07	2026-10-21 10:04:01.385793+07
627	agent-demo	hnth-branch-90	192.168.1.69	offline	236	75	0	2026-10-21 10:04:01.381+07	2026-10-21 10:04:01.386896+07
628	agent-demo	hnth-branch-73	192.168.1.68	offline	238	75	0	2026-10-21 10:04:04.867+07	2026-10-21 10:04:04.87134+07
629	agent-demo	hnth-branch-67	192.168.1.67	offline	242	75	0	2026-10-21 10:04:04.867+07	2026-10-21 10:04:04.873037+07
630	agent-demo	hnth-branch-76	192.168.1.66	offline	248	75	0	2026-10-21 10:04:08.37+07	2026-10-21 10:04:08.374245+07
631	agent-demo	hnth-branch-50	192.168.1.65	offline	253	75	0	2026-10-21 10:04:08.37+07	2026-10-21 10:04:08.375685+07
632	agent-demo	hnth-branch-81	192.168.1.64	offline	231	75	0	2026-10-21 10:04:11.874+07	2026-10-21 10:04:11.877878+07
633	agent-demo	hnth-branch-39	192.168.1.63	offline	235	75	0	2026-10-21 10:04:11.874+07	2026-10-21 10:04:11.880713+07
634	agent-demo	hnth-branch-84	192.168.1.62	offline	232	75	0	2026-10-21 10:04:15.373+07	2026-10-21 10:04:15.377102+07
635	agent-demo	hnth-branch-29	192.168.1.61	offline	237	75	0	2026-10-21 10:04:15.373+07	2026-10-21 10:04:15.379361+07
636	agent-demo	hnth-branch-53	192.168.1.60	offline	253	75	0	2026-10-21 10:04:18.869+07	2026-10-21 10:04:18.872508+07
637	agent-demo	hnth-branch-43	192.168.1.59	offline	249	75	0	2026-10-21 10:04:18.869+07	2026-10-21 10:04:18.873841+07
638	agent-demo	hnth-branch-100	192.168.1.58	offline	235	75	0	2026-10-21 10:04:22.381+07	2026-10-21 10:04:22.385067+07
639	agent-demo	hnth-branch-57	192.168.1.57	offline	231	75	0	2026-10-21 10:04:22.38+07	2026-10-21 10:04:22.386499+07
640	agent-demo	hnth-branch-109	192.168.1.56	offline	215	75	0	2026-10-21 10:04:25.879+07	2026-10-21 10:04:25.883312+07
641	agent-demo	hnth-branch-45	192.168.1.55	offline	239	75	0	2026-10-21 10:04:25.879+07	2026-10-21 10:04:25.885284+07
642	agent-demo	hnth-branch-55	192.168.1.54	offline	230	75	0	2026-10-21 10:04:29.399+07	2026-10-21 10:04:29.403731+07
643	agent-demo	hnth-branch-3	192.168.1.53	offline	236	75	0	2026-10-21 10:04:29.4+07	2026-10-21 10:04:29.405677+07
644	agent-demo	hnth-branch-111	192.168.1.52	online	84	0	41.67	2026-10-21 10:04:30.516+07	2026-10-21 10:04:32.870469+07
645	agent-demo	hnth-branch-36	192.168.1.51	offline	239	75	0	2026-10-21 10:04:32.867+07	2026-10-21 10:04:32.872036+07
646	agent-demo	hnth-branch-47	192.168.1.50	online	46	0	4.33	2026-10-21 10:04:33.84+07	2026-10-21 10:04:33.849073+07
647	agent-demo	hnth-branch-77	192.168.1.49	online	44	0	5	2026-10-21 10:04:33.843+07	2026-10-21 10:04:33.850653+07
648	agent-demo	hnth-branch-99	192.168.1.48	offline	235	75	0	2026-10-21 10:04:37.395+07	2026-10-21 10:04:37.399804+07
649	agent-demo	hnth-branch-26	192.168.1.47	offline	231	75	0	2026-10-21 10:04:37.393+07	2026-10-21 10:04:37.401732+07
650	agent-demo	hnth-branch-112	192.168.1.46	offline	254	75	0	2026-10-21 10:04:40.866+07	2026-10-21 10:04:40.870067+07
651	agent-demo	hnth-branch-65	192.168.1.45	offline	268	75	0	2026-10-21 10:04:40.866+07	2026-10-21 10:04:40.871414+07
652	agent-demo	hnth-branch-113	192.168.1.44	offline	242	75	0	2026-10-21 10:04:44.382+07	2026-10-21 10:04:44.387197+07
653	agent-demo	hnth-branch-88	192.168.1.43	offline	239	75	0	2026-10-21 10:04:44.382+07	2026-10-21 10:04:44.388821+07
654	agent-demo	hnth-branch-102	192.168.1.42	offline	235	75	0	2026-10-21 10:04:47.866+07	2026-10-21 10:04:47.869782+07
655	agent-demo	hnth-branch-7	192.168.1.41	offline	239	75	0	2026-10-21 10:04:47.866+07	2026-10-21 10:04:47.87124+07
656	agent-demo	hnth-branch-82	192.168.1.40	offline	229	75	0	2026-10-21 10:04:51.375+07	2026-10-21 10:04:51.380326+07
657	agent-demo	hnth-branch-51	192.168.1.39	offline	234	75	0	2026-10-21 10:04:51.375+07	2026-10-21 10:04:51.382585+07
658	agent-demo	hnth-branch-24	192.168.1.38	offline	224	75	0	2026-10-21 10:04:54.879+07	2026-10-21 10:04:54.883869+07
659	agent-demo	hnth-branch-25	192.168.1.37	offline	220	75	0	2026-10-21 10:04:54.88+07	2026-10-21 10:04:54.885094+07
660	agent-demo	hnth-branch-56	192.168.1.36	offline	235	75	0	2026-10-21 10:04:58.377+07	2026-10-21 10:04:58.384558+07
661	agent-demo	hnth-branch-87	192.168.1.15	offline	230	75	0	2026-10-21 10:04:58.377+07	2026-10-21 10:04:58.386403+07
662	agent-demo	hnth-branch-58	192.168.1.14	offline	237	75	0	2026-10-21 10:05:01.866+07	2026-10-21 10:05:01.87005+07
663	agent-demo	hnth-branch-105	192.168.1.13	offline	214	75	0	2026-10-21 10:05:01.866+07	2026-10-21 10:05:01.871723+07
664	agent-demo	hnth-branch-101	192.168.1.12	offline	238	75	0	2026-10-21 10:05:05.379+07	2026-10-21 10:05:05.383046+07
665	agent-demo	hnth-branch-79	192.168.1.11	offline	232	75	0	2026-10-21 10:05:05.379+07	2026-10-21 10:05:05.384389+07
666	agent-demo	hnth-branch-98	192.168.1.10	offline	235	75	0	2026-10-21 10:05:08.881+07	2026-10-21 10:05:08.884956+07
667	agent-demo	hnth-branch-66	192.168.1.9	offline	238	75	0	2026-10-21 10:05:08.881+07	2026-10-21 10:05:08.88705+07
668	agent-demo	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 10:05:12.874+07	2026-10-21 10:05:12.880004+07
669	agent-demo	hnth-branch-4	192.168.1.7	offline	238	75	0	2026-10-21 10:05:12.371+07	2026-10-21 10:05:12.882193+07
670	agent-demo	hnth-branch-30	192.168.1.6	online	56	0	12.67	2026-10-21 10:05:13.87+07	2026-10-21 10:05:13.887379+07
671	agent-demo	hnth-branch-21	192.168.1.5	online	55	0	13	2026-10-21 10:05:13.883+07	2026-10-21 10:05:13.888643+07
672	agent-demo	hnth-branch-28	192.168.1.4	online	47	0	15	2026-10-21 10:05:14.85+07	2026-10-21 10:05:17.374849+07
673	agent-demo	hnth-branch-23	192.168.1.3	offline	238	75	0	2026-10-21 10:05:17.369+07	2026-10-21 10:05:17.378582+07
674	agent-demo	hnth-branch-46	192.168.1.2	online	51	0	30	2026-10-21 10:05:18.361+07	2026-10-21 10:05:20.88573+07
675	agent-demo	hnth-branch-22	192.168.1.135	offline	242	75	0	2026-10-21 10:05:20.881+07	2026-10-21 10:05:20.887374+07
676	agent-demo	hnth-branch-37	192.168.1.0	offline	218	75	0	2026-10-21 10:05:24.38+07	2026-10-21 10:05:24.385042+07
677	agent-demo	hnth-branch-40	192.168.1.16	offline	222	75	0	2026-10-21 10:05:24.38+07	2026-10-21 10:05:24.386792+07
678	agent-demo	hnth-hub	192.168.1.169	offline	233	75	0	2026-10-21 10:08:37.381+07	2026-10-21 10:08:37.391372+07
679	agent-demo	hnth-hub	192.168.1.169	offline	251	75	0	2026-10-21 10:11:46.88+07	2026-10-21 10:11:46.887976+07
680	agent-demo	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 10:14:55.871+07	2026-10-21 10:14:55.87708+07
681	agent-demo	hnth-hub	192.168.1.169	offline	252	75	0	2026-10-21 10:18:04.872+07	2026-10-21 10:18:04.881702+07
682	agent-demo	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 10:21:14.37+07	2026-10-21 10:21:14.379853+07
683	agent-demo	hnth-hub	192.168.1.169	offline	225	75	0	2026-10-21 10:24:35.874+07	2026-10-21 10:24:35.884432+07
684	agent-demo	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 10:27:49.879+07	2026-10-21 10:27:49.885903+07
685	agent-demo	hnth-hub	192.168.1.169	offline	227	75	0	2026-10-21 10:53:03.374+07	2026-10-21 10:53:03.383675+07
686	agent-demo	hnth-branch-110	192.168.1.159	offline	239	75	0	2026-10-21 10:53:03.374+07	2026-10-21 10:53:03.395687+07
687	agent-demo	hnth-branch-13	192.168.1.158	offline	237	75	0	2026-10-21 10:53:06.874+07	2026-10-21 10:53:06.879563+07
688	agent-demo	hnth-branch-20	192.168.1.157	offline	227	75	0	2026-10-21 10:53:06.874+07	2026-10-21 10:53:06.881056+07
689	agent-demo	hnth-branch-2	192.168.1.156	offline	237	75	0	2026-10-21 10:53:10.366+07	2026-10-21 10:53:10.372267+07
690	agent-demo	hnth-branch-38	192.168.1.155	offline	227	75	0	2026-10-21 10:53:10.366+07	2026-10-21 10:53:10.374433+07
691	agent-demo	hnth-branch-35	192.168.1.161	offline	239	75	0	2026-10-21 10:53:13.879+07	2026-10-21 10:53:13.886536+07
692	agent-demo	hnth-branch-33	192.168.1.126	offline	229	75	0	2026-10-21 10:53:13.879+07	2026-10-21 10:53:13.88836+07
693	agent-demo	hnth-branch-31	192.168.1.125	offline	215	75	0	2026-10-21 10:53:17.371+07	2026-10-21 10:53:17.376433+07
694	agent-demo	hnth-branch-89	192.168.1.124	offline	224	75	0	2026-10-21 10:53:17.371+07	2026-10-21 10:53:17.379089+07
695	agent-demo	hnth-branch-34	192.168.1.123	offline	237	75	0	2026-10-21 10:53:20.881+07	2026-10-21 10:53:20.885044+07
696	agent-demo	hnth-branch-93	192.168.1.122	offline	228	75	0	2026-10-21 10:53:20.881+07	2026-10-21 10:53:20.886828+07
697	agent-demo	hnth-branch-32	192.168.1.121	offline	237	75	0	2026-10-21 10:53:24.376+07	2026-10-21 10:53:24.380346+07
698	agent-demo	hnth-branch-18	192.168.1.120	offline	227	75	0	2026-10-21 10:53:24.376+07	2026-10-21 10:53:24.381931+07
699	agent-demo	hnth-branch-1	192.168.1.160	online	54	0	10.67	2026-10-21 10:53:25.36+07	2026-10-21 10:53:27.874359+07
700	agent-demo	hnth-branch-108	192.168.1.118	offline	224	75	0	2026-10-21 10:53:27.87+07	2026-10-21 10:53:27.87729+07
701	agent-demo	hnth-branch-42	192.168.1.117	offline	223	75	0	2026-10-21 10:53:31.374+07	2026-10-21 10:53:31.379937+07
702	agent-demo	hnth-branch-62	192.168.1.116	offline	233	75	0	2026-10-21 10:53:31.374+07	2026-10-21 10:53:31.38183+07
703	agent-demo	hnth-branch-69	192.168.1.1	online	52	0	12.33	2026-10-21 10:53:32.366+07	2026-10-21 10:53:34.875407+07
704	agent-demo	hnth-branch-59	192.168.1.114	offline	222	75	0	2026-10-21 10:53:34.868+07	2026-10-21 10:53:34.879505+07
705	agent-demo	hnth-branch-64	192.168.1.113	offline	235	75	0	2026-10-21 10:53:38.374+07	2026-10-21 10:53:38.378917+07
706	agent-demo	hnth-branch-27	192.168.1.112	offline	226	75	0	2026-10-21 10:53:38.374+07	2026-10-21 10:53:38.380493+07
707	agent-demo	hnth-branch-107	192.168.1.111	offline	239	75	0	2026-10-21 10:53:41.878+07	2026-10-21 10:53:41.882269+07
708	agent-demo	hnth-branch-97	192.168.1.110	offline	229	75	0	2026-10-21 10:53:41.878+07	2026-10-21 10:53:41.883787+07
709	agent-demo	hnth-branch-106	192.168.1.109	offline	224	75	0	2026-10-21 10:53:45.366+07	2026-10-21 10:53:45.369962+07
710	agent-demo	hnth-branch-75	192.168.1.108	offline	215	75	0	2026-10-21 10:53:45.366+07	2026-10-21 10:53:45.371488+07
711	agent-demo	hnth-branch-92	192.168.1.107	offline	238	75	0	2026-10-21 10:53:48.874+07	2026-10-21 10:53:48.878081+07
712	agent-demo	hnth-branch-70	192.168.1.106	offline	228	75	0	2026-10-21 10:53:48.873+07	2026-10-21 10:53:48.879788+07
713	agent-demo	hnth-branch-83	192.168.1.105	offline	230	75	0	2026-10-21 10:53:52.376+07	2026-10-21 10:53:52.380407+07
714	agent-demo	hnth-branch-63	192.168.1.104	offline	239	75	0	2026-10-21 10:53:52.376+07	2026-10-21 10:53:52.38217+07
715	agent-demo	hnth-branch-68	192.168.1.103	offline	230	75	0	2026-10-21 10:53:55.866+07	2026-10-21 10:53:55.87037+07
716	agent-demo	hnth-branch-78	192.168.1.102	offline	239	75	0	2026-10-21 10:53:55.867+07	2026-10-21 10:53:55.871793+07
717	agent-demo	hnth-branch-14	192.168.1.101	offline	240	75	0	2026-10-21 10:53:59.375+07	2026-10-21 10:53:59.380465+07
718	agent-demo	hnth-branch-96	192.168.1.100	offline	230	75	0	2026-10-21 10:53:59.375+07	2026-10-21 10:53:59.38294+07
719	agent-demo	hnth-branch-86	192.168.1.99	offline	228	75	0	2026-10-21 10:54:02.873+07	2026-10-21 10:54:02.880775+07
720	agent-demo	hnth-branch-94	192.168.1.98	offline	237	75	0	2026-10-21 10:54:02.873+07	2026-10-21 10:54:02.882658+07
721	agent-demo	hnth-branch-91	192.168.1.97	offline	217	75	0	2026-10-21 10:54:06.379+07	2026-10-21 10:54:06.383544+07
722	agent-demo	hnth-branch-11	192.168.1.96	offline	226	75	0	2026-10-21 10:54:06.38+07	2026-10-21 10:54:06.385013+07
723	agent-demo	hnth-branch-85	192.168.1.95	offline	240	75	0	2026-10-21 10:54:09.866+07	2026-10-21 10:54:09.870374+07
724	agent-demo	hnth-branch-41	192.168.1.94	offline	229	75	0	2026-10-21 10:54:09.867+07	2026-10-21 10:54:09.871498+07
725	agent-demo	hnth-branch-17	192.168.1.93	offline	224	75	0	2026-10-21 10:54:13.376+07	2026-10-21 10:54:13.379802+07
726	agent-demo	hnth-branch-6	192.168.1.92	offline	216	75	0	2026-10-21 10:54:13.376+07	2026-10-21 10:54:13.381268+07
727	agent-demo	hnth-branch-15	192.168.1.91	offline	230	75	0	2026-10-21 10:54:16.875+07	2026-10-21 10:54:16.879464+07
728	agent-demo	hnth-branch-49	192.168.1.90	offline	240	75	0	2026-10-21 10:54:16.875+07	2026-10-21 10:54:16.88098+07
729	agent-demo	hnth-branch-104	192.168.1.89	offline	238	75	0	2026-10-21 10:54:20.379+07	2026-10-21 10:54:20.383699+07
730	agent-demo	hnth-branch-16	192.168.1.87	offline	230	75	0	2026-10-21 10:54:20.379+07	2026-10-21 10:54:20.385338+07
731	agent-demo	hnth-branch-60	192.168.1.86	offline	240	75	0	2026-10-21 10:54:23.876+07	2026-10-21 10:54:23.880204+07
732	agent-demo	hnth-branch-48	192.168.1.85	offline	227	75	0	2026-10-21 10:54:23.876+07	2026-10-21 10:54:23.881547+07
733	agent-demo	hnth-branch-10	192.168.1.84	offline	215	75	0	2026-10-21 10:54:27.378+07	2026-10-21 10:54:27.381715+07
734	agent-demo	hnth-branch-72	192.168.1.83	offline	223	75	0	2026-10-21 10:54:27.378+07	2026-10-21 10:54:27.383467+07
735	agent-demo	hnth-branch-74	192.168.1.82	offline	239	75	0	2026-10-21 10:54:30.868+07	2026-10-21 10:54:30.873382+07
736	agent-demo	hnth-branch-9	192.168.1.81	offline	229	75	0	2026-10-21 10:54:30.869+07	2026-10-21 10:54:30.875948+07
737	agent-demo	hnth-branch-8	192.168.1.80	offline	236	75	0	2026-10-21 10:54:34.377+07	2026-10-21 10:54:34.381261+07
738	agent-demo	hnth-branch-103	192.168.1.79	offline	227	75	0	2026-10-21 10:54:34.377+07	2026-10-21 10:54:34.382674+07
739	agent-demo	hnth-branch-52	192.168.1.78	offline	234	75	0	2026-10-21 10:54:37.875+07	2026-10-21 10:54:37.880632+07
740	agent-demo	hnth-branch-44	192.168.1.77	offline	225	75	0	2026-10-21 10:54:37.875+07	2026-10-21 10:54:37.883175+07
741	agent-demo	hnth-branch-95	192.168.1.76	offline	238	75	0	2026-10-21 10:54:41.372+07	2026-10-21 10:54:41.377149+07
742	agent-demo	hnth-branch-12	192.168.1.75	offline	228	75	0	2026-10-21 10:54:41.371+07	2026-10-21 10:54:41.378577+07
743	agent-demo	hnth-branch-54	192.168.1.74	offline	238	75	0	2026-10-21 10:54:44.875+07	2026-10-21 10:54:44.878977+07
744	agent-demo	hnth-branch-5	192.168.1.73	offline	229	75	0	2026-10-21 10:54:44.875+07	2026-10-21 10:54:44.880453+07
745	agent-demo	hnth-branch-114	192.168.1.72	offline	235	75	0	2026-10-21 10:54:48.38+07	2026-10-21 10:54:48.390002+07
746	agent-demo	hnth-branch-19	192.168.1.71	offline	226	75	0	2026-10-21 10:54:48.38+07	2026-10-21 10:54:48.393665+07
747	agent-demo	hnth-branch-61	192.168.1.70	offline	241	75	0	2026-10-21 10:54:51.882+07	2026-10-21 10:54:51.887711+07
748	agent-demo	hnth-branch-90	192.168.1.69	offline	217	75	0	2026-10-21 10:54:51.882+07	2026-10-21 10:54:51.891139+07
749	agent-demo	hnth-branch-73	192.168.1.68	offline	220	75	0	2026-10-21 10:54:55.372+07	2026-10-21 10:54:55.377996+07
750	agent-demo	hnth-branch-67	192.168.1.67	offline	244	75	0	2026-10-21 10:54:55.372+07	2026-10-21 10:54:55.379867+07
751	agent-demo	hnth-branch-76	192.168.1.66	offline	240	75	0	2026-10-21 10:54:58.878+07	2026-10-21 10:54:58.884766+07
752	agent-demo	hnth-branch-50	192.168.1.65	offline	214	75	0	2026-10-21 10:54:58.878+07	2026-10-21 10:54:58.886808+07
753	agent-demo	hnth-branch-81	192.168.1.64	offline	237	75	0	2026-10-21 10:55:02.373+07	2026-10-21 10:55:02.381917+07
754	agent-demo	hnth-branch-39	192.168.1.63	offline	228	75	0	2026-10-21 10:55:02.373+07	2026-10-21 10:55:02.384418+07
755	agent-demo	hnth-branch-84	192.168.1.62	offline	237	75	0	2026-10-21 10:55:05.872+07	2026-10-21 10:55:05.876485+07
756	agent-demo	hnth-branch-29	192.168.1.61	offline	226	75	0	2026-10-21 10:55:05.872+07	2026-10-21 10:55:05.877751+07
757	agent-demo	hnth-branch-53	192.168.1.60	offline	239	75	0	2026-10-21 10:55:09.376+07	2026-10-21 10:55:09.380856+07
758	agent-demo	hnth-branch-43	192.168.1.59	offline	230	75	0	2026-10-21 10:55:09.376+07	2026-10-21 10:55:09.382558+07
759	agent-demo	hnth-branch-100	192.168.1.58	offline	253	75	0	2026-10-21 10:55:12.867+07	2026-10-21 10:55:12.871409+07
760	agent-demo	hnth-branch-57	192.168.1.57	offline	239	75	0	2026-10-21 10:55:12.867+07	2026-10-21 10:55:12.872869+07
761	agent-demo	hnth-branch-109	192.168.1.56	offline	245	75	0	2026-10-21 10:55:16.375+07	2026-10-21 10:55:16.381759+07
762	agent-demo	hnth-branch-45	192.168.1.55	offline	254	75	0	2026-10-21 10:55:16.375+07	2026-10-21 10:55:16.384669+07
763	agent-demo	hnth-branch-55	192.168.1.54	offline	229	75	0	2026-10-21 10:55:19.882+07	2026-10-21 10:55:19.890323+07
764	agent-demo	hnth-branch-3	192.168.1.53	offline	239	75	0	2026-10-21 10:55:19.882+07	2026-10-21 10:55:19.894299+07
765	agent-demo	hnth-branch-111	192.168.1.52	online	53	0	20	2026-10-21 10:55:20.941+07	2026-10-21 10:55:23.379731+07
766	agent-demo	hnth-branch-36	192.168.1.51	offline	240	75	0	2026-10-21 10:55:23.376+07	2026-10-21 10:55:23.381203+07
767	agent-demo	hnth-branch-47	192.168.1.50	online	53	0	5.33	2026-10-21 10:55:24.377+07	2026-10-21 10:55:24.395229+07
768	agent-demo	hnth-branch-77	192.168.1.49	online	49	0	4.67	2026-10-21 10:55:24.392+07	2026-10-21 10:55:24.396385+07
769	agent-demo	hnth-branch-99	192.168.1.48	offline	240	75	0	2026-10-21 10:55:27.879+07	2026-10-21 10:55:27.883431+07
770	agent-demo	hnth-branch-26	192.168.1.47	offline	232	75	0	2026-10-21 10:55:27.879+07	2026-10-21 10:55:27.88474+07
771	agent-demo	hnth-branch-112	192.168.1.46	offline	243	75	0	2026-10-21 10:55:31.375+07	2026-10-21 10:55:31.381558+07
772	agent-demo	hnth-branch-65	192.168.1.45	offline	221	75	0	2026-10-21 10:55:31.375+07	2026-10-21 10:55:31.383257+07
773	agent-demo	hnth-branch-113	192.168.1.44	offline	215	75	0	2026-10-21 10:55:34.874+07	2026-10-21 10:55:34.878335+07
774	agent-demo	hnth-branch-88	192.168.1.43	offline	236	75	0	2026-10-21 10:55:34.874+07	2026-10-21 10:55:34.879741+07
775	agent-demo	hnth-branch-102	192.168.1.42	offline	239	75	0	2026-10-21 10:55:38.373+07	2026-10-21 10:55:38.377266+07
776	agent-demo	hnth-branch-7	192.168.1.41	offline	231	75	0	2026-10-21 10:55:38.373+07	2026-10-21 10:55:38.379054+07
777	agent-demo	hnth-branch-82	192.168.1.40	offline	241	75	0	2026-10-21 10:55:41.878+07	2026-10-21 10:55:41.886694+07
778	agent-demo	hnth-branch-51	192.168.1.39	offline	219	75	0	2026-10-21 10:55:41.878+07	2026-10-21 10:55:41.890828+07
779	agent-demo	hnth-branch-24	192.168.1.38	offline	226	75	0	2026-10-21 10:55:45.369+07	2026-10-21 10:55:45.373802+07
780	agent-demo	hnth-branch-25	192.168.1.37	offline	238	75	0	2026-10-21 10:55:45.37+07	2026-10-21 10:55:45.375137+07
781	agent-demo	hnth-branch-56	192.168.1.36	offline	237	75	0	2026-10-21 10:55:48.872+07	2026-10-21 10:55:48.876016+07
782	agent-demo	hnth-branch-87	192.168.1.15	offline	224	75	0	2026-10-21 10:55:48.872+07	2026-10-21 10:55:48.877412+07
783	agent-demo	hnth-branch-58	192.168.1.14	offline	257	75	0	2026-10-21 10:55:52.383+07	2026-10-21 10:55:52.390124+07
784	agent-demo	hnth-branch-105	192.168.1.13	offline	235	75	0	2026-10-21 10:55:52.383+07	2026-10-21 10:55:52.393046+07
785	agent-demo	hnth-branch-101	192.168.1.12	offline	242	75	0	2026-10-21 10:55:55.878+07	2026-10-21 10:55:55.89002+07
786	agent-demo	hnth-branch-79	192.168.1.11	offline	221	75	0	2026-10-21 10:55:55.878+07	2026-10-21 10:55:55.893008+07
787	agent-demo	hnth-branch-98	192.168.1.10	offline	242	75	0	2026-10-21 10:55:59.378+07	2026-10-21 10:55:59.383714+07
788	agent-demo	hnth-branch-66	192.168.1.9	offline	232	75	0	2026-10-21 10:55:59.378+07	2026-10-21 10:55:59.385862+07
789	agent-demo	hnth-branch-80	192.168.1.8	online	85	0	51.67	2026-10-21 10:56:00.507+07	2026-10-21 10:56:02.881817+07
790	agent-demo	hnth-branch-4	192.168.1.7	offline	240	75	0	2026-10-21 10:56:02.877+07	2026-10-21 10:56:02.883638+07
791	agent-demo	hnth-branch-30	192.168.1.6	online	49	0	9	2026-10-21 10:56:03.857+07	2026-10-21 10:56:03.867171+07
792	agent-demo	hnth-branch-21	192.168.1.5	online	44	0	3	2026-10-21 10:56:03.863+07	2026-10-21 10:56:03.868319+07
793	agent-demo	hnth-branch-28	192.168.1.4	online	47	0	8.67	2026-10-21 10:56:04.834+07	2026-10-21 10:56:07.392511+07
794	agent-demo	hnth-branch-23	192.168.1.3	offline	236	75	0	2026-10-21 10:56:07.384+07	2026-10-21 10:56:07.396525+07
795	agent-demo	hnth-branch-46	192.168.1.2	online	58	0	13.33	2026-10-21 10:56:08.419+07	2026-10-21 10:56:10.869593+07
796	agent-demo	hnth-branch-22	192.168.1.135	offline	232	75	0	2026-10-21 10:56:10.865+07	2026-10-21 10:56:10.871926+07
797	agent-demo	hnth-branch-37	192.168.1.0	offline	229	75	0	2026-10-21 10:56:14.376+07	2026-10-21 10:56:14.381084+07
798	agent-demo	hnth-branch-40	192.168.1.16	offline	251	75	0	2026-10-21 10:56:14.376+07	2026-10-21 10:56:14.38272+07
799	agent-demo	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 11:21:17.375+07	2026-10-21 11:21:17.380407+07
800	agent-demo	hnth-branch-110	192.168.1.159	offline	233	75	0	2026-10-21 11:21:17.375+07	2026-10-21 11:21:17.392096+07
801	agent-demo	hnth-branch-13	192.168.1.158	offline	236	75	0	2026-10-21 11:21:20.876+07	2026-10-21 11:21:20.879196+07
802	agent-demo	hnth-branch-20	192.168.1.157	offline	232	75	0	2026-10-21 11:21:20.875+07	2026-10-21 11:21:20.880445+07
803	agent-demo	hnth-branch-2	192.168.1.156	offline	230	75	0	2026-10-21 11:21:24.379+07	2026-10-21 11:21:24.385283+07
804	agent-demo	hnth-branch-38	192.168.1.155	offline	235	75	0	2026-10-21 11:21:24.379+07	2026-10-21 11:21:24.387598+07
805	agent-demo	hnth-branch-35	192.168.1.161	offline	250	75	0	2026-10-21 11:21:27.874+07	2026-10-21 11:21:27.880957+07
806	agent-demo	hnth-branch-33	192.168.1.126	offline	246	75	0	2026-10-21 11:21:27.874+07	2026-10-21 11:21:27.882599+07
807	agent-demo	hnth-branch-31	192.168.1.125	offline	237	75	0	2026-10-21 11:21:31.376+07	2026-10-21 11:21:31.380604+07
808	agent-demo	hnth-branch-89	192.168.1.124	offline	212	75	0	2026-10-21 11:21:31.376+07	2026-10-21 11:21:31.381908+07
809	agent-demo	hnth-branch-34	192.168.1.123	offline	234	75	0	2026-10-21 11:21:34.868+07	2026-10-21 11:21:34.872341+07
810	agent-demo	hnth-branch-93	192.168.1.122	offline	239	75	0	2026-10-21 11:21:34.868+07	2026-10-21 11:21:34.873686+07
811	agent-demo	hnth-branch-32	192.168.1.121	offline	239	75	0	2026-10-21 11:21:38.375+07	2026-10-21 11:21:38.378796+07
812	agent-demo	hnth-branch-18	192.168.1.120	offline	235	75	0	2026-10-21 11:21:38.375+07	2026-10-21 11:21:38.380094+07
813	agent-demo	hnth-branch-1	192.168.1.160	online	43	0	17	2026-10-21 11:21:39.339+07	2026-10-21 11:21:41.931449+07
814	agent-demo	hnth-branch-108	192.168.1.118	offline	250	75	0	2026-10-21 11:21:41.877+07	2026-10-21 11:21:41.932981+07
815	agent-demo	hnth-branch-42	192.168.1.117	offline	232	75	0	2026-10-21 11:21:45.378+07	2026-10-21 11:21:45.382117+07
816	agent-demo	hnth-branch-62	192.168.1.116	offline	236	75	0	2026-10-21 11:21:45.378+07	2026-10-21 11:21:45.383764+07
817	agent-demo	hnth-branch-69	192.168.1.1	online	42	0	13	2026-10-21 11:21:46.328+07	2026-10-21 11:21:48.885209+07
818	agent-demo	hnth-branch-59	192.168.1.114	offline	235	75	0	2026-10-21 11:21:48.88+07	2026-10-21 11:21:48.887249+07
819	agent-demo	hnth-branch-64	192.168.1.113	offline	239	75	0	2026-10-21 11:21:52.376+07	2026-10-21 11:21:52.379985+07
820	agent-demo	hnth-branch-27	192.168.1.112	offline	235	75	0	2026-10-21 11:21:52.376+07	2026-10-21 11:21:52.381389+07
821	agent-demo	hnth-branch-107	192.168.1.111	offline	237	75	0	2026-10-21 11:21:55.866+07	2026-10-21 11:21:55.871172+07
822	agent-demo	hnth-branch-97	192.168.1.110	offline	233	75	0	2026-10-21 11:21:55.867+07	2026-10-21 11:21:55.872413+07
823	agent-demo	hnth-branch-106	192.168.1.109	offline	248	75	0	2026-10-21 11:21:59.378+07	2026-10-21 11:21:59.383474+07
824	agent-demo	hnth-branch-75	192.168.1.108	offline	244	75	0	2026-10-21 11:21:59.377+07	2026-10-21 11:21:59.387423+07
825	agent-demo	hnth-branch-92	192.168.1.107	offline	236	75	0	2026-10-21 11:22:02.866+07	2026-10-21 11:22:02.873479+07
826	agent-demo	hnth-branch-70	192.168.1.106	offline	232	75	0	2026-10-21 11:22:02.866+07	2026-10-21 11:22:02.875136+07
827	agent-demo	hnth-branch-83	192.168.1.105	offline	248	75	0	2026-10-21 11:22:06.373+07	2026-10-21 11:22:06.377236+07
828	agent-demo	hnth-branch-63	192.168.1.104	offline	252	75	0	2026-10-21 11:22:06.373+07	2026-10-21 11:22:06.378551+07
829	agent-demo	hnth-branch-68	192.168.1.103	offline	231	75	0	2026-10-21 11:22:09.87+07	2026-10-21 11:22:09.876938+07
830	agent-demo	hnth-branch-78	192.168.1.102	offline	235	75	0	2026-10-21 11:22:09.87+07	2026-10-21 11:22:09.878512+07
831	agent-demo	hnth-branch-14	192.168.1.101	offline	231	75	0	2026-10-21 11:22:13.369+07	2026-10-21 11:22:13.373926+07
832	agent-demo	hnth-branch-96	192.168.1.100	offline	235	75	0	2026-10-21 11:22:13.369+07	2026-10-21 11:22:13.375487+07
833	agent-demo	hnth-branch-86	192.168.1.99	offline	234	75	0	2026-10-21 11:22:16.867+07	2026-10-21 11:22:16.871228+07
834	agent-demo	hnth-branch-94	192.168.1.98	offline	230	75	0	2026-10-21 11:22:16.867+07	2026-10-21 11:22:16.872497+07
835	agent-demo	hnth-branch-91	192.168.1.97	offline	230	75	0	2026-10-21 11:22:20.366+07	2026-10-21 11:22:20.373778+07
836	agent-demo	hnth-branch-11	192.168.1.96	offline	234	75	0	2026-10-21 11:22:20.366+07	2026-10-21 11:22:20.375398+07
837	agent-demo	hnth-branch-85	192.168.1.95	offline	236	75	0	2026-10-21 11:22:23.868+07	2026-10-21 11:22:23.872216+07
838	agent-demo	hnth-branch-41	192.168.1.94	offline	233	75	0	2026-10-21 11:22:23.868+07	2026-10-21 11:22:23.873467+07
839	agent-demo	hnth-branch-17	192.168.1.93	offline	235	75	0	2026-10-21 11:22:27.374+07	2026-10-21 11:22:27.378573+07
840	agent-demo	hnth-branch-6	192.168.1.92	offline	232	75	0	2026-10-21 11:22:27.37+07	2026-10-21 11:22:27.380166+07
843	agent-demo	hnth-branch-104	192.168.1.89	offline	236	75	0	2026-10-21 11:22:34.367+07	2026-10-21 11:22:34.371818+07
844	agent-demo	hnth-branch-16	192.168.1.87	offline	239	75	0	2026-10-21 11:22:34.367+07	2026-10-21 11:22:34.373244+07
845	agent-demo	hnth-branch-60	192.168.1.86	offline	238	75	0	2026-10-21 11:22:37.867+07	2026-10-21 11:22:37.871833+07
846	agent-demo	hnth-branch-48	192.168.1.85	offline	234	75	0	2026-10-21 11:22:37.867+07	2026-10-21 11:22:37.873167+07
853	agent-demo	hnth-branch-52	192.168.1.78	offline	238	75	0	2026-10-21 11:22:51.884+07	2026-10-21 11:22:51.891761+07
854	agent-demo	hnth-branch-44	192.168.1.77	offline	234	75	0	2026-10-21 11:22:51.884+07	2026-10-21 11:22:51.894737+07
857	agent-demo	hnth-branch-54	192.168.1.74	offline	237	75	0	2026-10-21 11:22:58.879+07	2026-10-21 11:22:58.8882+07
858	agent-demo	hnth-branch-5	192.168.1.73	offline	242	75	0	2026-10-21 11:22:58.879+07	2026-10-21 11:22:58.892039+07
1351	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	239	75	0	2026-10-21 18:00:06.369+07	2026-10-21 18:00:06.376102+07
1352	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	231	75	0	2026-10-21 18:00:06.368+07	2026-10-21 18:00:06.378+07
1353	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	237	75	0	2026-10-21 18:00:09.866+07	2026-10-21 18:00:09.870178+07
1354	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	229	75	0	2026-10-21 18:00:09.866+07	2026-10-21 18:00:09.871332+07
1357	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	242	75	0	2026-10-21 18:00:16.871+07	2026-10-21 18:00:16.876216+07
1358	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	234	75	0	2026-10-21 18:00:16.872+07	2026-10-21 18:00:16.877675+07
1365	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	255	75	0	2026-10-21 18:00:30.879+07	2026-10-21 18:00:30.8833+07
1366	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	245	75	0	2026-10-21 18:00:30.879+07	2026-10-21 18:00:30.8846+07
1371	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	233	75	0	2026-10-21 18:00:41.37+07	2026-10-21 18:00:41.373946+07
1372	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	240	75	0	2026-10-21 18:00:41.37+07	2026-10-21 18:00:41.375276+07
1375	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	225	75	0	2026-10-21 18:00:48.374+07	2026-10-21 18:00:48.377997+07
1376	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	218	75	0	2026-10-21 18:00:48.374+07	2026-10-21 18:00:48.379287+07
1377	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	217	75	0	2026-10-21 18:00:51.871+07	2026-10-21 18:00:51.875762+07
1378	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	225	75	0	2026-10-21 18:00:51.871+07	2026-10-21 18:00:51.877036+07
1429	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 18:30:27.377+07	2026-10-21 18:30:27.882448+07
1478	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	226	75	0	2026-10-21 18:44:06.374+07	2026-10-21 18:44:06.381283+07
1479	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	234	75	0	2026-10-21 18:44:06.374+07	2026-10-21 18:44:06.383377+07
1480	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	234	75	0	2026-10-21 18:44:09.869+07	2026-10-21 18:44:09.874469+07
1481	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	241	75	0	2026-10-21 18:44:09.869+07	2026-10-21 18:44:09.876135+07
1484	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	239	75	0	2026-10-21 18:44:16.879+07	2026-10-21 18:44:16.883377+07
1485	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	228	75	0	2026-10-21 18:44:16.879+07	2026-10-21 18:44:16.886192+07
1488	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	233	75	0	2026-10-21 18:44:23.912+07	2026-10-21 18:44:23.91718+07
1489	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	241	75	0	2026-10-21 18:44:23.909+07	2026-10-21 18:44:23.920996+07
1490	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	224	75	0	2026-10-21 18:44:27.375+07	2026-10-21 18:44:27.379119+07
1491	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	215	75	0	2026-10-21 18:44:27.375+07	2026-10-21 18:44:27.380477+07
1494	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	217	75	0	2026-10-21 18:44:34.367+07	2026-10-21 18:44:34.371934+07
1495	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	241	75	0	2026-10-21 18:44:34.367+07	2026-10-21 18:44:34.373275+07
1498	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	241	75	0	2026-10-21 18:44:41.38+07	2026-10-21 18:44:41.383818+07
1499	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	232	75	0	2026-10-21 18:44:41.38+07	2026-10-21 18:44:41.385741+07
1502	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	210	75	0	2026-10-21 18:44:48.38+07	2026-10-21 18:44:48.384078+07
1503	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	234	75	0	2026-10-21 18:44:48.38+07	2026-10-21 18:44:48.386188+07
1508	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	218	75	0	2026-10-21 18:44:58.874+07	2026-10-21 18:44:58.878492+07
1509	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	239	75	0	2026-10-21 18:44:58.874+07	2026-10-21 18:44:58.879952+07
1555	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	233	75	0	2026-10-21 19:02:56.379+07	2026-10-21 19:02:56.389328+07
1556	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	245	75	0	2026-10-21 19:02:56.379+07	2026-10-21 19:02:56.392832+07
1559	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	234	75	0	2026-10-21 19:03:03.382+07	2026-10-21 19:03:03.394014+07
1560	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	246	75	0	2026-10-21 19:03:03.383+07	2026-10-21 19:03:03.399235+07
1561	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	240	75	0	2026-10-21 19:03:06.869+07	2026-10-21 19:03:06.873709+07
1562	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	230	75	0	2026-10-21 19:03:06.869+07	2026-10-21 19:03:06.875184+07
1563	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	245	75	0	2026-10-21 19:03:10.368+07	2026-10-21 19:03:10.376063+07
1564	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	235	75	0	2026-10-21 19:03:10.369+07	2026-10-21 19:03:10.380098+07
1567	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	236	75	0	2026-10-21 19:03:17.382+07	2026-10-21 19:03:17.388459+07
1568	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	243	75	0	2026-10-21 19:03:17.381+07	2026-10-21 19:03:17.391784+07
1569	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	83	0	12	2026-10-21 19:03:18.513+07	2026-10-21 19:03:20.881927+07
1570	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	237	75	0	2026-10-21 19:03:20.878+07	2026-10-21 19:03:20.884193+07
1571	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	241	75	0	2026-10-21 19:03:24.384+07	2026-10-21 19:03:24.389661+07
1572	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	230	75	0	2026-10-21 19:03:24.383+07	2026-10-21 19:03:24.392598+07
1575	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	243	75	0	2026-10-21 19:03:31.381+07	2026-10-21 19:03:31.390172+07
1576	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	235	75	0	2026-10-21 19:03:31.381+07	2026-10-21 19:03:31.39483+07
1577	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	233	75	0	2026-10-21 19:03:34.875+07	2026-10-21 19:03:34.882288+07
1578	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	244	75	0	2026-10-21 19:03:34.875+07	2026-10-21 19:03:34.885011+07
841	agent-demo	hnth-branch-15	192.168.1.91	offline	235	75	0	2026-10-21 11:22:30.869+07	2026-10-21 11:22:30.873644+07
842	agent-demo	hnth-branch-49	192.168.1.90	offline	231	75	0	2026-10-21 11:22:30.869+07	2026-10-21 11:22:30.875099+07
847	agent-demo	hnth-branch-10	192.168.1.84	offline	231	75	0	2026-10-21 11:22:41.37+07	2026-10-21 11:22:41.377682+07
848	agent-demo	hnth-branch-72	192.168.1.83	offline	235	75	0	2026-10-21 11:22:41.371+07	2026-10-21 11:22:41.379193+07
849	agent-demo	hnth-branch-74	192.168.1.82	offline	241	75	0	2026-10-21 11:22:44.869+07	2026-10-21 11:22:44.873235+07
850	agent-demo	hnth-branch-9	192.168.1.81	offline	230	75	0	2026-10-21 11:22:44.869+07	2026-10-21 11:22:44.874574+07
851	agent-demo	hnth-branch-8	192.168.1.80	offline	246	75	0	2026-10-21 11:22:48.376+07	2026-10-21 11:22:48.380982+07
852	agent-demo	hnth-branch-103	192.168.1.79	offline	251	75	0	2026-10-21 11:22:48.377+07	2026-10-21 11:22:48.382782+07
855	agent-demo	hnth-branch-95	192.168.1.76	offline	238	75	0	2026-10-21 11:22:55.377+07	2026-10-21 11:22:55.38582+07
856	agent-demo	hnth-branch-12	192.168.1.75	offline	232	75	0	2026-10-21 11:22:55.377+07	2026-10-21 11:22:55.388631+07
859	agent-demo	hnth-branch-114	192.168.1.72	offline	242	75	0	2026-10-21 11:23:02.377+07	2026-10-21 11:23:02.387826+07
860	agent-demo	hnth-branch-19	192.168.1.71	offline	239	75	0	2026-10-21 11:23:02.377+07	2026-10-21 11:23:02.390719+07
861	agent-demo	hnth-branch-61	192.168.1.70	offline	234	75	0	2026-10-21 11:23:05.869+07	2026-10-21 11:23:05.875131+07
862	agent-demo	hnth-branch-90	192.168.1.69	offline	228	75	0	2026-10-21 11:23:05.869+07	2026-10-21 11:23:05.87724+07
863	agent-demo	hnth-branch-73	192.168.1.68	offline	236	75	0	2026-10-21 11:23:09.891+07	2026-10-21 11:23:09.894965+07
864	agent-demo	hnth-branch-67	192.168.1.67	offline	233	75	0	2026-10-21 11:23:09.885+07	2026-10-21 11:23:09.89627+07
865	agent-demo	hnth-branch-76	192.168.1.66	offline	233	75	0	2026-10-21 11:23:13.372+07	2026-10-21 11:23:13.378846+07
866	agent-demo	hnth-branch-50	192.168.1.65	offline	228	75	0	2026-10-21 11:23:13.372+07	2026-10-21 11:23:13.380388+07
867	agent-demo	hnth-branch-81	192.168.1.64	offline	250	75	0	2026-10-21 11:23:16.865+07	2026-10-21 11:23:16.869451+07
868	agent-demo	hnth-branch-39	192.168.1.63	offline	244	75	0	2026-10-21 11:23:16.865+07	2026-10-21 11:23:16.870765+07
869	agent-demo	hnth-branch-84	192.168.1.62	offline	230	75	0	2026-10-21 11:23:20.375+07	2026-10-21 11:23:20.382207+07
870	agent-demo	hnth-branch-29	192.168.1.61	offline	234	75	0	2026-10-21 11:23:20.375+07	2026-10-21 11:23:20.383833+07
871	agent-demo	hnth-branch-53	192.168.1.60	offline	245	75	0	2026-10-21 11:23:23.869+07	2026-10-21 11:23:23.873031+07
872	agent-demo	hnth-branch-43	192.168.1.59	offline	250	75	0	2026-10-21 11:23:23.868+07	2026-10-21 11:23:23.874324+07
873	agent-demo	hnth-branch-100	192.168.1.58	offline	232	75	0	2026-10-21 11:23:27.37+07	2026-10-21 11:23:27.375029+07
874	agent-demo	hnth-branch-57	192.168.1.57	offline	236	75	0	2026-10-21 11:23:27.37+07	2026-10-21 11:23:27.376498+07
875	agent-demo	hnth-branch-109	192.168.1.56	offline	231	75	0	2026-10-21 11:23:30.866+07	2026-10-21 11:23:30.870615+07
876	agent-demo	hnth-branch-45	192.168.1.55	offline	235	75	0	2026-10-21 11:23:30.866+07	2026-10-21 11:23:30.872165+07
877	agent-demo	hnth-branch-55	192.168.1.54	offline	243	75	0	2026-10-21 11:23:34.374+07	2026-10-21 11:23:34.384989+07
878	agent-demo	hnth-branch-3	192.168.1.53	offline	233	75	0	2026-10-21 11:23:34.374+07	2026-10-21 11:23:34.38726+07
879	agent-demo	hnth-branch-111	192.168.1.52	online	35	0	5	2026-10-21 11:23:35.321+07	2026-10-21 11:23:37.883174+07
880	agent-demo	hnth-branch-36	192.168.1.51	offline	236	75	0	2026-10-21 11:23:37.878+07	2026-10-21 11:23:37.885086+07
881	agent-demo	hnth-branch-47	192.168.1.50	online	44	0	6.33	2026-10-21 11:23:38.833+07	2026-10-21 11:23:38.841003+07
882	agent-demo	hnth-branch-77	192.168.1.49	online	41	0	5	2026-10-21 11:23:38.837+07	2026-10-21 11:23:38.84226+07
883	agent-demo	hnth-branch-99	192.168.1.48	offline	241	75	0	2026-10-21 11:23:42.376+07	2026-10-21 11:23:42.381522+07
884	agent-demo	hnth-branch-26	192.168.1.47	offline	233	75	0	2026-10-21 11:23:42.376+07	2026-10-21 11:23:42.38325+07
885	agent-demo	hnth-branch-112	192.168.1.46	offline	238	75	0	2026-10-21 11:23:45.878+07	2026-10-21 11:23:45.883825+07
886	agent-demo	hnth-branch-65	192.168.1.45	offline	234	75	0	2026-10-21 11:23:45.879+07	2026-10-21 11:23:45.885476+07
887	agent-demo	hnth-branch-113	192.168.1.44	offline	234	75	0	2026-10-21 11:23:49.375+07	2026-10-21 11:23:49.3824+07
888	agent-demo	hnth-branch-88	192.168.1.43	offline	238	75	0	2026-10-21 11:23:49.375+07	2026-10-21 11:23:49.384402+07
889	agent-demo	hnth-branch-102	192.168.1.42	offline	244	75	0	2026-10-21 11:23:52.871+07	2026-10-21 11:23:52.881035+07
890	agent-demo	hnth-branch-7	192.168.1.41	offline	248	75	0	2026-10-21 11:23:52.871+07	2026-10-21 11:23:52.883515+07
891	agent-demo	hnth-branch-82	192.168.1.40	offline	236	75	0	2026-10-21 11:23:56.381+07	2026-10-21 11:23:56.385237+07
892	agent-demo	hnth-branch-51	192.168.1.39	offline	230	75	0	2026-10-21 11:23:56.381+07	2026-10-21 11:23:56.386454+07
893	agent-demo	hnth-branch-24	192.168.1.38	offline	228	75	0	2026-10-21 11:23:59.883+07	2026-10-21 11:23:59.89471+07
894	agent-demo	hnth-branch-25	192.168.1.37	offline	237	75	0	2026-10-21 11:23:59.883+07	2026-10-21 11:23:59.898175+07
895	agent-demo	hnth-branch-56	192.168.1.36	offline	231	75	0	2026-10-21 11:24:03.367+07	2026-10-21 11:24:03.373629+07
896	agent-demo	hnth-branch-87	192.168.1.15	offline	235	75	0	2026-10-21 11:24:03.367+07	2026-10-21 11:24:03.375197+07
897	agent-demo	hnth-branch-58	192.168.1.14	offline	242	75	0	2026-10-21 11:24:06.88+07	2026-10-21 11:24:06.885573+07
898	agent-demo	hnth-branch-105	192.168.1.13	offline	234	75	0	2026-10-21 11:24:06.881+07	2026-10-21 11:24:06.887567+07
899	agent-demo	hnth-branch-101	192.168.1.12	offline	237	75	0	2026-10-21 11:24:10.369+07	2026-10-21 11:24:10.374018+07
900	agent-demo	hnth-branch-79	192.168.1.11	offline	232	75	0	2026-10-21 11:24:10.369+07	2026-10-21 11:24:10.375981+07
901	agent-demo	hnth-branch-98	192.168.1.10	offline	236	75	0	2026-10-21 11:24:13.87+07	2026-10-21 11:24:13.874515+07
902	agent-demo	hnth-branch-66	192.168.1.9	offline	232	75	0	2026-10-21 11:24:13.87+07	2026-10-21 11:24:13.876164+07
903	agent-demo	hnth-branch-80	192.168.1.8	online	113	0	80	2026-10-21 11:24:15.1+07	2026-10-21 11:24:17.379563+07
904	agent-demo	hnth-branch-4	192.168.1.7	offline	237	75	0	2026-10-21 11:24:17.373+07	2026-10-21 11:24:17.382205+07
905	agent-demo	hnth-branch-30	192.168.1.6	online	42	0	7	2026-10-21 11:24:18.326+07	2026-10-21 11:24:18.333224+07
906	agent-demo	hnth-branch-21	192.168.1.5	online	40	0	4.33	2026-10-21 11:24:18.329+07	2026-10-21 11:24:18.334443+07
907	agent-demo	hnth-branch-28	192.168.1.4	online	39	0	3	2026-10-21 11:24:19.27+07	2026-10-21 11:24:21.885347+07
908	agent-demo	hnth-branch-23	192.168.1.3	offline	254	75	0	2026-10-21 11:24:21.877+07	2026-10-21 11:24:21.888084+07
909	agent-demo	hnth-branch-46	192.168.1.2	online	40	0	5.33	2026-10-21 11:24:22.834+07	2026-10-21 11:24:25.382077+07
910	agent-demo	hnth-branch-22	192.168.1.135	offline	248	75	0	2026-10-21 11:24:25.376+07	2026-10-21 11:24:25.385302+07
911	agent-demo	hnth-branch-37	192.168.1.0	offline	249	75	0	2026-10-21 11:24:28.869+07	2026-10-21 11:24:28.874326+07
912	agent-demo	hnth-branch-40	192.168.1.16	offline	254	75	0	2026-10-21 11:24:28.869+07	2026-10-21 11:24:28.875871+07
913	agent-demo	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 11:27:38.869+07	2026-10-21 11:27:38.882228+07
914	agent-demo	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 11:30:45.374+07	2026-10-21 11:30:45.380343+07
915	agent-demo	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 11:33:51.374+07	2026-10-21 11:33:51.380392+07
916	agent-demo	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-21 11:36:57.882+07	2026-10-21 11:36:57.900519+07
917	agent-demo	hnth-hub	192.168.1.169	offline	234	75	0	2026-10-21 11:40:03.881+07	2026-10-21 11:40:03.888122+07
918	agent-demo	hnth-hub	192.168.1.169	offline	247	75	0	2026-10-21 11:43:10.374+07	2026-10-21 11:43:10.380277+07
919	agent-demo	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 11:46:16.869+07	2026-10-21 11:46:16.875432+07
920	agent-demo	hnth-hub	192.168.1.169	offline	243	75	0	2026-10-21 11:49:23.377+07	2026-10-21 11:49:23.384865+07
921	agent-demo	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 11:52:29.369+07	2026-10-21 11:52:29.378133+07
922	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	729	75	0	2026-10-21 11:52:48.372+07	2026-10-21 11:52:48.390725+07
923	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-110	192.168.1.159	offline	721	75	0	2026-10-21 11:52:48.372+07	2026-10-21 11:52:48.395623+07
924	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-13	192.168.1.158	offline	731	75	0	2026-10-21 11:52:52.383+07	2026-10-21 11:52:52.396031+07
925	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-20	192.168.1.157	offline	722	75	0	2026-10-21 11:52:52.382+07	2026-10-21 11:52:52.400257+07
932	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-34	192.168.1.123	offline	723	75	0	2026-10-21 11:53:08.379+07	2026-10-21 11:53:08.389639+07
933	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-93	192.168.1.122	offline	732	75	0	2026-10-21 11:53:08.378+07	2026-10-21 11:53:08.394422+07
936	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-1	192.168.1.160	online	43	0	4	2026-10-21 11:53:12.829+07	2026-10-21 11:53:15.372308+07
937	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-108	192.168.1.118	offline	227	75	0	2026-10-21 11:53:15.368+07	2026-10-21 11:53:15.373689+07
938	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-42	192.168.1.117	offline	226	75	0	2026-10-21 11:53:18.884+07	2026-10-21 11:53:18.887709+07
939	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-62	192.168.1.116	offline	239	75	0	2026-10-21 11:53:18.883+07	2026-10-21 11:53:18.889143+07
940	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-69	192.168.1.1	online	53	0	8.67	2026-10-21 11:53:19.874+07	2026-10-21 11:53:22.379288+07
941	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-59	192.168.1.114	offline	239	75	0	2026-10-21 11:53:22.372+07	2026-10-21 11:53:22.382786+07
952	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-68	192.168.1.103	offline	238	75	0	2026-10-21 11:53:43.373+07	2026-10-21 11:53:43.382156+07
953	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-78	192.168.1.102	offline	229	75	0	2026-10-21 11:53:43.373+07	2026-10-21 11:53:43.387557+07
954	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-14	192.168.1.101	offline	245	75	0	2026-10-21 11:53:46.867+07	2026-10-21 11:53:46.873559+07
955	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-96	192.168.1.100	offline	219	75	0	2026-10-21 11:53:46.867+07	2026-10-21 11:53:46.875013+07
956	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-86	192.168.1.99	offline	241	75	0	2026-10-21 11:53:50.375+07	2026-10-21 11:53:50.381299+07
957	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-94	192.168.1.98	offline	225	75	0	2026-10-21 11:53:50.375+07	2026-10-21 11:53:50.383645+07
964	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-15	192.168.1.91	offline	239	75	0	2026-10-21 11:54:04.379+07	2026-10-21 11:54:04.386683+07
965	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-49	192.168.1.90	offline	223	75	0	2026-10-21 11:54:04.379+07	2026-10-21 11:54:04.38942+07
968	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-60	192.168.1.86	offline	244	75	0	2026-10-21 11:54:11.38+07	2026-10-21 11:54:11.383508+07
969	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-48	192.168.1.85	offline	232	75	0	2026-10-21 11:54:11.38+07	2026-10-21 11:54:11.384818+07
970	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-10	192.168.1.84	offline	230	75	0	2026-10-21 11:54:14.88+07	2026-10-21 11:54:14.884988+07
971	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-72	192.168.1.83	offline	210	75	0	2026-10-21 11:54:14.88+07	2026-10-21 11:54:14.887189+07
974	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-8	192.168.1.80	offline	214	75	0	2026-10-21 11:54:21.872+07	2026-10-21 11:54:21.879054+07
975	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-103	192.168.1.79	offline	239	75	0	2026-10-21 11:54:21.872+07	2026-10-21 11:54:21.881578+07
980	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-54	192.168.1.74	offline	227	75	0	2026-10-21 11:54:32.377+07	2026-10-21 11:54:32.382343+07
981	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-5	192.168.1.73	offline	238	75	0	2026-10-21 11:54:32.377+07	2026-10-21 11:54:32.385009+07
984	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-61	192.168.1.70	offline	245	75	0	2026-10-21 11:54:39.376+07	2026-10-21 11:54:39.380379+07
985	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-90	192.168.1.69	offline	217	75	0	2026-10-21 11:54:39.376+07	2026-10-21 11:54:39.381817+07
1379	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	240	75	0	2026-10-21 18:00:55.372+07	2026-10-21 18:00:55.378049+07
1380	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	232	75	0	2026-10-21 18:00:55.372+07	2026-10-21 18:00:55.380138+07
1389	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	237	75	0	2026-10-21 18:01:10.378+07	2026-10-21 18:01:10.382963+07
1390	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	230	75	0	2026-10-21 18:01:10.378+07	2026-10-21 18:01:10.384339+07
1391	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	241	75	0	2026-10-21 18:01:13.868+07	2026-10-21 18:01:13.872281+07
1392	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	233	75	0	2026-10-21 18:01:13.868+07	2026-10-21 18:01:13.873567+07
1395	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	254	75	0	2026-10-21 18:01:20.87+07	2026-10-21 18:01:20.875038+07
1396	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	247	75	0	2026-10-21 18:01:20.87+07	2026-10-21 18:01:20.876338+07
1397	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	223	75	0	2026-10-21 18:01:24.367+07	2026-10-21 18:01:24.370971+07
1398	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	215	75	0	2026-10-21 18:01:24.367+07	2026-10-21 18:01:24.372203+07
1399	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	246	75	0	2026-10-21 18:01:27.872+07	2026-10-21 18:01:27.87677+07
1400	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	254	75	0	2026-10-21 18:01:27.872+07	2026-10-21 18:01:27.87806+07
1403	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	230	75	0	2026-10-21 18:01:34.877+07	2026-10-21 18:01:34.881839+07
1404	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	238	75	0	2026-10-21 18:01:34.877+07	2026-10-21 18:01:34.883672+07
1407	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	242	75	0	2026-10-21 18:01:42.375+07	2026-10-21 18:01:42.379244+07
1408	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	234	75	0	2026-10-21 18:01:42.375+07	2026-10-21 18:01:42.382011+07
1411	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	48	0	6.33	2026-10-21 18:01:47.339+07	2026-10-21 18:01:47.375043+07
1412	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	53	0	14.33	2026-10-21 18:01:47.371+07	2026-10-21 18:01:47.376768+07
1430	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	230	75	0	2026-10-21 18:33:37.38+07	2026-10-21 18:33:37.389482+07
1510	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	237	75	0	2026-10-21 18:45:02.376+07	2026-10-21 18:45:02.382536+07
1511	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	217	75	0	2026-10-21 18:45:02.376+07	2026-10-21 18:45:02.38425+07
1514	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	216	75	0	2026-10-21 18:45:09.375+07	2026-10-21 18:45:09.385701+07
1515	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	245	75	0	2026-10-21 18:45:09.375+07	2026-10-21 18:45:09.391107+07
1518	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	56	0	20	2026-10-21 18:45:13.873+07	2026-10-21 18:45:13.887465+07
1519	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	52	0	7.67	2026-10-21 18:45:13.883+07	2026-10-21 18:45:13.888853+07
1522	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	239	75	0	2026-10-21 18:45:20.881+07	2026-10-21 18:45:20.886212+07
1523	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	211	75	0	2026-10-21 18:45:20.881+07	2026-10-21 18:45:20.88852+07
1528	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	238	75	0	2026-10-21 18:45:31.378+07	2026-10-21 18:45:31.382043+07
1529	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	246	75	0	2026-10-21 18:45:31.378+07	2026-10-21 18:45:31.383375+07
1532	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	235	75	0	2026-10-21 18:45:38.375+07	2026-10-21 18:45:38.379423+07
926	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-2	192.168.1.156	offline	727	75	0	2026-10-21 11:52:56.374+07	2026-10-21 11:52:56.385608+07
927	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-38	192.168.1.155	offline	743	75	0	2026-10-21 11:52:56.375+07	2026-10-21 11:52:56.38914+07
930	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-31	192.168.1.125	offline	726	75	0	2026-10-21 11:53:04.371+07	2026-10-21 11:53:04.377367+07
931	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-89	192.168.1.124	offline	718	75	0	2026-10-21 11:53:04.371+07	2026-10-21 11:53:04.379136+07
934	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-32	192.168.1.121	offline	227	75	0	2026-10-21 11:53:11.875+07	2026-10-21 11:53:11.879242+07
935	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-18	192.168.1.120	offline	242	75	0	2026-10-21 11:53:11.875+07	2026-10-21 11:53:11.880447+07
942	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-64	192.168.1.113	offline	236	75	0	2026-10-21 11:53:25.877+07	2026-10-21 11:53:25.88262+07
943	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-27	192.168.1.112	offline	225	75	0	2026-10-21 11:53:25.877+07	2026-10-21 11:53:25.88477+07
946	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-106	192.168.1.109	offline	240	75	0	2026-10-21 11:53:32.875+07	2026-10-21 11:53:32.879076+07
947	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-75	192.168.1.108	offline	213	75	0	2026-10-21 11:53:32.875+07	2026-10-21 11:53:32.880632+07
948	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-92	192.168.1.107	offline	235	75	0	2026-10-21 11:53:36.381+07	2026-10-21 11:53:36.391501+07
949	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-70	192.168.1.106	offline	243	75	0	2026-10-21 11:53:36.381+07	2026-10-21 11:53:36.397355+07
1381	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	239	75	0	2026-10-21 18:00:58.874+07	2026-10-21 18:00:58.87987+07
1382	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	231	75	0	2026-10-21 18:00:58.874+07	2026-10-21 18:00:58.881321+07
1383	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	242	75	0	2026-10-21 18:01:02.372+07	2026-10-21 18:01:02.376516+07
1384	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	234	75	0	2026-10-21 18:01:02.372+07	2026-10-21 18:01:02.378022+07
1385	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	45	0	4.33	2026-10-21 18:01:03.326+07	2026-10-21 18:01:05.884131+07
1386	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	237	75	0	2026-10-21 18:01:05.88+07	2026-10-21 18:01:05.885403+07
1387	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	50	0	9	2026-10-21 18:01:06.859+07	2026-10-21 18:01:06.863848+07
1388	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	47	0	5.67	2026-10-21 18:01:06.853+07	2026-10-21 18:01:06.865301+07
1393	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	238	75	0	2026-10-21 18:01:17.368+07	2026-10-21 18:01:17.372453+07
1394	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	230	75	0	2026-10-21 18:01:17.368+07	2026-10-21 18:01:17.37367+07
1401	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	228	75	0	2026-10-21 18:01:31.38+07	2026-10-21 18:01:31.384997+07
1402	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	237	75	0	2026-10-21 18:01:31.38+07	2026-10-21 18:01:31.387968+07
1405	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	247	75	0	2026-10-21 18:01:38.366+07	2026-10-21 18:01:38.876827+07
1406	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 18:01:38.873+07	2026-10-21 18:01:38.878199+07
1409	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 18:01:46.374+07	2026-10-21 18:01:46.378458+07
1410	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 18:01:46.374+07	2026-10-21 18:01:46.379764+07
1413	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	50	0	11.33	2026-10-21 18:01:48.351+07	2026-10-21 18:01:50.883684+07
1414	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	251	75	0	2026-10-21 18:01:50.878+07	2026-10-21 18:01:50.88555+07
1415	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	50	0	11.67	2026-10-21 18:01:51.855+07	2026-10-21 18:01:54.377691+07
1416	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	240	75	0	2026-10-21 18:01:54.373+07	2026-10-21 18:01:54.379205+07
1417	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	216	75	0	2026-10-21 18:01:57.869+07	2026-10-21 18:01:57.873279+07
1418	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	225	75	0	2026-10-21 18:01:57.869+07	2026-10-21 18:01:57.874902+07
1431	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 18:36:46.367+07	2026-10-21 18:36:46.373857+07
1533	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	217	75	0	2026-10-21 18:45:38.375+07	2026-10-21 18:45:38.380746+07
1536	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	239	75	0	2026-10-21 18:45:45.369+07	2026-10-21 18:45:45.873578+07
1537	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 18:45:45.87+07	2026-10-21 18:45:45.874895+07
1540	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	237	75	0	2026-10-21 18:45:52.867+07	2026-10-21 18:45:52.871084+07
1541	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	127	0	69.67	2026-10-21 18:45:50.666+07	2026-10-21 18:45:52.872426+07
1557	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	222	75	0	2026-10-21 19:02:59.873+07	2026-10-21 19:02:59.880412+07
1558	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	226	75	0	2026-10-21 19:02:59.873+07	2026-10-21 19:02:59.882055+07
1565	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	232	75	0	2026-10-21 19:03:13.879+07	2026-10-21 19:03:13.884691+07
1566	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	240	75	0	2026-10-21 19:03:13.879+07	2026-10-21 19:03:13.886655+07
1573	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	65	0	16.67	2026-10-21 19:03:25.433+07	2026-10-21 19:03:27.883345+07
1574	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	243	75	0	2026-10-21 19:03:27.879+07	2026-10-21 19:03:27.88482+07
1581	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	234	75	0	2026-10-21 19:03:41.885+07	2026-10-21 19:03:41.893789+07
1582	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	245	75	0	2026-10-21 19:03:41.885+07	2026-10-21 19:03:41.897609+07
1613	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	65	0	11	2026-10-21 19:18:33.927+07	2026-10-21 19:18:36.394663+07
1614	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	238	75	0	2026-10-21 19:18:36.381+07	2026-10-21 19:18:36.396889+07
1710	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	239	75	0	2026-10-21 19:21:20.375+07	2026-10-21 19:21:20.380685+07
1715	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 19:30:49.372+07	2026-10-21 19:30:49.380846+07
1719	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 19:36:57.37+07	2026-10-21 19:36:57.379352+07
1723	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	unknown	294	50	509	2026-10-21 19:42:59.487+07	2026-10-21 19:42:59.877342+07
1724	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	242	75	0	2026-10-21 19:43:19.383+07	2026-10-21 19:43:19.389779+07
1728	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	236	75	0	2026-10-21 19:49:35.371+07	2026-10-21 19:49:35.377409+07
1731	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	129	0	68.67	2026-10-21 19:55:45.534+07	2026-10-21 19:55:45.542343+07
1733	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	unknown	339	50	538	2026-10-21 19:58:54.067+07	2026-10-21 19:58:54.886015+07
928	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-35	192.168.1.161	offline	742	75	0	2026-10-21 11:53:00.378+07	2026-10-21 11:53:00.382459+07
929	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-33	192.168.1.126	offline	716	75	0	2026-10-21 11:53:00.378+07	2026-10-21 11:53:00.384016+07
944	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-107	192.168.1.111	offline	245	75	0	2026-10-21 11:53:29.377+07	2026-10-21 11:53:29.385414+07
945	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-97	192.168.1.110	offline	217	75	0	2026-10-21 11:53:29.376+07	2026-10-21 11:53:29.387405+07
950	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-83	192.168.1.105	offline	243	75	0	2026-10-21 11:53:39.866+07	2026-10-21 11:53:39.871017+07
951	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-63	192.168.1.104	offline	218	75	0	2026-10-21 11:53:39.866+07	2026-10-21 11:53:39.873901+07
958	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-91	192.168.1.97	offline	244	75	0	2026-10-21 11:53:53.87+07	2026-10-21 11:53:53.882095+07
959	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-11	192.168.1.96	offline	220	75	0	2026-10-21 11:53:53.87+07	2026-10-21 11:53:53.884498+07
960	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-85	192.168.1.95	offline	228	75	0	2026-10-21 11:53:57.38+07	2026-10-21 11:53:57.385747+07
961	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-41	192.168.1.94	offline	242	75	0	2026-10-21 11:53:57.38+07	2026-10-21 11:53:57.388565+07
962	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-17	192.168.1.93	offline	242	75	0	2026-10-21 11:54:00.874+07	2026-10-21 11:54:00.884538+07
963	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-6	192.168.1.92	offline	217	75	0	2026-10-21 11:54:00.874+07	2026-10-21 11:54:00.887193+07
966	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-104	192.168.1.89	offline	244	75	0	2026-10-21 11:54:07.871+07	2026-10-21 11:54:07.881224+07
967	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-16	192.168.1.87	offline	219	75	0	2026-10-21 11:54:07.871+07	2026-10-21 11:54:07.883595+07
972	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-74	192.168.1.82	offline	240	75	0	2026-10-21 11:54:18.373+07	2026-10-21 11:54:18.385641+07
973	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-9	192.168.1.81	offline	224	75	0	2026-10-21 11:54:18.373+07	2026-10-21 11:54:18.389221+07
976	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-52	192.168.1.78	offline	240	75	0	2026-10-21 11:54:25.371+07	2026-10-21 11:54:25.378386+07
977	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-44	192.168.1.77	offline	225	75	0	2026-10-21 11:54:25.371+07	2026-10-21 11:54:25.38271+07
978	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-95	192.168.1.76	offline	243	75	0	2026-10-21 11:54:28.877+07	2026-10-21 11:54:28.883932+07
979	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-12	192.168.1.75	offline	219	75	0	2026-10-21 11:54:28.877+07	2026-10-21 11:54:28.887368+07
982	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-114	192.168.1.72	offline	244	75	0	2026-10-21 11:54:35.869+07	2026-10-21 11:54:35.874865+07
983	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-19	192.168.1.71	offline	219	75	0	2026-10-21 11:54:35.869+07	2026-10-21 11:54:35.876888+07
986	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-73	192.168.1.68	offline	231	75	0	2026-10-21 11:54:42.88+07	2026-10-21 11:54:42.883979+07
987	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-67	192.168.1.67	offline	239	75	0	2026-10-21 11:54:42.88+07	2026-10-21 11:54:42.885274+07
988	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-76	192.168.1.66	offline	242	75	0	2026-10-21 11:54:46.371+07	2026-10-21 11:54:46.375638+07
989	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-50	192.168.1.65	offline	228	75	0	2026-10-21 11:54:46.371+07	2026-10-21 11:54:46.377058+07
990	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-81	192.168.1.64	offline	242	75	0	2026-10-21 11:54:49.876+07	2026-10-21 11:54:49.880911+07
991	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-39	192.168.1.63	offline	220	75	0	2026-10-21 11:54:49.876+07	2026-10-21 11:54:49.88291+07
992	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-84	192.168.1.62	offline	203	75	0	2026-10-21 11:54:53.376+07	2026-10-21 11:54:53.391161+07
993	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-29	192.168.1.61	offline	224	75	0	2026-10-21 11:54:53.376+07	2026-10-21 11:54:53.395041+07
994	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-53	192.168.1.60	offline	239	75	0	2026-10-21 11:54:56.877+07	2026-10-21 11:54:56.881239+07
995	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-43	192.168.1.59	offline	228	75	0	2026-10-21 11:54:56.877+07	2026-10-21 11:54:56.882603+07
996	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-100	192.168.1.58	offline	210	75	0	2026-10-21 11:55:00.374+07	2026-10-21 11:55:00.379458+07
997	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-57	192.168.1.57	offline	246	75	0	2026-10-21 11:55:00.374+07	2026-10-21 11:55:00.382039+07
998	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-109	192.168.1.56	offline	241	75	0	2026-10-21 11:55:03.874+07	2026-10-21 11:55:03.882894+07
999	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-45	192.168.1.55	offline	215	75	0	2026-10-21 11:55:03.874+07	2026-10-21 11:55:03.888929+07
1000	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-55	192.168.1.54	offline	240	75	0	2026-10-21 11:55:07.366+07	2026-10-21 11:55:07.372456+07
1001	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-3	192.168.1.53	offline	226	75	0	2026-10-21 11:55:07.366+07	2026-10-21 11:55:07.375281+07
1002	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-111	192.168.1.52	online	83	0	22.67	2026-10-21 11:55:08.485+07	2026-10-21 11:55:10.879926+07
1003	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-36	192.168.1.51	offline	225	75	0	2026-10-21 11:55:10.874+07	2026-10-21 11:55:10.882735+07
1004	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-47	192.168.1.50	online	69	0	16.67	2026-10-21 11:55:11.942+07	2026-10-21 11:55:11.95384+07
1005	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-77	192.168.1.49	online	64	0	13.33	2026-10-21 11:55:11.949+07	2026-10-21 11:55:11.955741+07
1006	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-99	192.168.1.48	offline	228	75	0	2026-10-21 11:55:15.386+07	2026-10-21 11:55:15.404479+07
1007	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-26	192.168.1.47	offline	236	75	0	2026-10-21 11:55:15.386+07	2026-10-21 11:55:15.409618+07
1008	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-112	192.168.1.46	offline	228	75	0	2026-10-21 11:55:18.873+07	2026-10-21 11:55:18.8782+07
1009	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-65	192.168.1.45	offline	240	75	0	2026-10-21 11:55:18.873+07	2026-10-21 11:55:18.880319+07
1010	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-113	192.168.1.44	offline	241	75	0	2026-10-21 11:55:22.384+07	2026-10-21 11:55:22.38806+07
1011	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-88	192.168.1.43	offline	218	75	0	2026-10-21 11:55:22.384+07	2026-10-21 11:55:22.389469+07
1012	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-102	192.168.1.42	offline	247	75	0	2026-10-21 11:55:25.882+07	2026-10-21 11:55:25.88874+07
1013	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-7	192.168.1.41	offline	259	75	0	2026-10-21 11:55:25.881+07	2026-10-21 11:55:25.891237+07
1014	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-82	192.168.1.40	offline	212	75	0	2026-10-21 11:55:29.371+07	2026-10-21 11:55:29.375783+07
1015	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-51	192.168.1.39	offline	228	75	0	2026-10-21 11:55:29.372+07	2026-10-21 11:55:29.377235+07
1016	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-24	192.168.1.38	offline	232	75	0	2026-10-21 11:55:32.875+07	2026-10-21 11:55:32.881603+07
1017	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-25	192.168.1.37	offline	242	75	0	2026-10-21 11:55:32.875+07	2026-10-21 11:55:32.883255+07
1018	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-56	192.168.1.36	offline	222	75	0	2026-10-21 11:55:36.371+07	2026-10-21 11:55:36.376243+07
1019	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-87	192.168.1.15	offline	237	75	0	2026-10-21 11:55:36.371+07	2026-10-21 11:55:36.377843+07
1020	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-58	192.168.1.14	offline	242	75	0	2026-10-21 11:55:39.882+07	2026-10-21 11:55:39.888946+07
1021	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-105	192.168.1.13	offline	218	75	0	2026-10-21 11:55:39.882+07	2026-10-21 11:55:39.891741+07
1022	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-101	192.168.1.12	offline	257	75	0	2026-10-21 11:55:43.378+07	2026-10-21 11:55:43.396629+07
1023	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	online	126	0	39	2026-10-21 11:55:41.194+07	2026-10-21 11:55:43.403732+07
1024	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-98	192.168.1.10	offline	240	75	0	2026-10-21 11:55:46.866+07	2026-10-21 11:55:46.87248+07
1025	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-66	192.168.1.9	offline	215	75	0	2026-10-21 11:55:46.866+07	2026-10-21 11:55:46.876124+07
1026	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-80	192.168.1.8	online	130	0	81.33	2026-10-21 11:55:48.166+07	2026-10-21 11:55:50.379862+07
1027	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-4	192.168.1.7	offline	239	75	0	2026-10-21 11:55:50.372+07	2026-10-21 11:55:50.381302+07
1028	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-30	192.168.1.6	online	63	0	15.67	2026-10-21 11:55:51.415+07	2026-10-21 11:55:51.428392+07
1029	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-21	192.168.1.5	online	49	0	6.33	2026-10-21 11:55:51.424+07	2026-10-21 11:55:51.4296+07
1030	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-28	192.168.1.4	online	62	0	26.67	2026-10-21 11:55:52.451+07	2026-10-21 11:55:54.879293+07
1031	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-23	192.168.1.3	offline	238	75	0	2026-10-21 11:55:54.873+07	2026-10-21 11:55:54.880729+07
1032	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-46	192.168.1.2	online	53	0	17.33	2026-10-21 11:55:55.867+07	2026-10-21 11:55:58.383173+07
1033	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-22	192.168.1.135	offline	238	75	0	2026-10-21 11:55:58.378+07	2026-10-21 11:55:58.385121+07
1034	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-37	192.168.1.0	offline	225	75	0	2026-10-21 11:56:01.872+07	2026-10-21 11:56:01.876551+07
1035	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-40	192.168.1.16	offline	218	75	0	2026-10-21 11:56:01.872+07	2026-10-21 11:56:01.878205+07
1036	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	225	75	0	2026-10-21 11:59:11.871+07	2026-10-21 11:59:11.887473+07
1037	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 12:02:15.871+07	2026-10-21 12:02:15.883392+07
1038	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	212	75	0	2026-10-21 12:02:21.377+07	2026-10-21 12:02:21.384791+07
1039	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 12:05:27.879+07	2026-10-21 12:05:27.886044+07
1040	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 12:05:33.372+07	2026-10-21 12:05:33.384281+07
1041	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-80	192.168.1.8	online	125	0	91.33	2026-10-21 12:08:22.644+07	2026-10-21 12:08:24.886845+07
1042	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	248	75	0	2026-10-21 12:08:42.875+07	2026-10-21 12:08:42.885631+07
1043	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	228	75	0	2026-10-21 12:11:49.87+07	2026-10-21 12:11:49.878104+07
1044	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-21 12:14:56.375+07	2026-10-21 12:14:56.38246+07
1045	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	online	98	0	69.67	2026-10-21 12:17:41.527+07	2026-10-21 12:17:43.874127+07
1046	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 12:18:02.88+07	2026-10-21 12:18:02.895215+07
1047	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 12:21:09.874+07	2026-10-21 12:21:09.886689+07
1048	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-21 12:24:16.375+07	2026-10-21 12:24:16.384864+07
1049	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	230	75	0	2026-10-21 12:27:23.373+07	2026-10-21 12:27:23.380971+07
1050	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	230	75	0	2026-10-21 12:30:29.874+07	2026-10-21 12:30:29.88123+07
1051	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	220	75	0	2026-10-21 12:33:36.368+07	2026-10-21 12:33:36.377801+07
1052	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 12:36:42.872+07	2026-10-21 12:36:42.887893+07
1053	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	230	75	0	2026-10-21 12:39:49.378+07	2026-10-21 12:39:49.386093+07
1054	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	227	75	0	2026-10-21 12:42:55.867+07	2026-10-21 12:42:55.957922+07
1055	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 12:45:59.877+07	2026-10-21 12:45:59.885065+07
1056	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 12:46:05.367+07	2026-10-21 12:46:05.373618+07
1057	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 12:49:12.371+07	2026-10-21 12:49:12.377226+07
1058	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	online	138	0	28	2026-10-21 12:51:57.699+07	2026-10-21 12:51:59.883022+07
1059	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-21 12:52:18.877+07	2026-10-21 12:52:18.885017+07
1060	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-21 12:55:25.376+07	2026-10-21 12:55:25.383286+07
1061	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	224	75	0	2026-10-21 12:58:31.882+07	2026-10-21 12:58:31.888673+07
1062	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-21 13:01:38.375+07	2026-10-21 13:01:38.381329+07
1063	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 13:04:42.384+07	2026-10-21 13:04:42.389012+07
1064	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	233	75	0	2026-10-21 13:04:47.875+07	2026-10-21 13:04:47.881814+07
1065	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	online	139	0	22.33	2026-10-21 13:07:33.219+07	2026-10-21 13:07:35.38393+07
1066	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 13:07:54.378+07	2026-10-21 13:07:54.385815+07
1067	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 13:11:00.876+07	2026-10-21 13:11:00.937886+07
1068	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	242	75	0	2026-10-21 13:14:07.384+07	2026-10-21 13:14:07.391253+07
1069	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-21 13:17:13.883+07	2026-10-21 13:17:13.888501+07
1070	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 13:20:20.372+07	2026-10-21 13:20:20.378439+07
1071	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	offline	112	75	0	2026-10-21 13:23:23.371+07	2026-10-21 13:23:23.876335+07
1072	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 13:23:23.87+07	2026-10-21 13:23:23.878636+07
1073	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 13:23:29.373+07	2026-10-21 13:23:29.384423+07
1074	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	online	62	0	19	2026-10-21 13:26:14.382+07	2026-10-21 13:26:16.889123+07
1075	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	247	75	0	2026-10-21 13:26:38.882+07	2026-10-21 13:26:38.891831+07
1076	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-80	192.168.1.8	online	81	0	16.33	2026-10-21 13:29:27.462+07	2026-10-21 13:29:29.889824+07
1077	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 13:29:45.869+07	2026-10-21 13:29:45.877752+07
1078	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 13:32:49.878+07	2026-10-21 13:32:49.885234+07
1079	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-21 13:32:49.878+07	2026-10-21 13:32:49.887383+07
1080	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 13:32:55.371+07	2026-10-21 13:32:55.376612+07
1081	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	online	153	0	5	2026-10-21 13:35:40.754+07	2026-10-21 13:35:42.881295+07
1082	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 13:36:04.878+07	2026-10-21 13:36:04.884775+07
1083	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	223	75	0	2026-10-21 13:39:12.365+07	2026-10-21 13:39:12.371087+07
1084	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	302	75	0	2026-10-21 13:42:19.367+07	2026-10-21 13:42:19.374696+07
1085	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-21 13:45:25.872+07	2026-10-21 13:45:25.884393+07
1086	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 13:48:29.873+07	2026-10-21 13:48:29.881199+07
1087	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	210	75	0	2026-10-21 13:48:35.377+07	2026-10-21 13:48:35.395774+07
1088	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	234	75	0	2026-10-21 13:51:45.871+07	2026-10-21 13:51:45.877491+07
1089	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-21 13:54:55.383+07	2026-10-21 13:54:55.396828+07
1090	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 13:58:04.369+07	2026-10-21 13:58:04.376351+07
1091	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-21 14:01:13.875+07	2026-10-21 14:01:13.883511+07
1092	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	242	75	0	2026-10-21 14:04:22.385+07	2026-10-21 14:04:22.892107+07
1093	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-85	192.168.1.95	offline	237	75	0	2026-10-21 14:05:26.383+07	2026-10-21 14:05:26.388941+07
1094	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-41	192.168.1.94	offline	228	75	0	2026-10-21 14:05:26.383+07	2026-10-21 14:05:26.39057+07
1095	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	212	75	0	2026-10-21 14:05:26.383+07	2026-10-21 14:05:26.870546+07
1096	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-110	192.168.1.159	offline	735	75	0	2026-10-21 14:05:26.865+07	2026-10-21 14:05:26.872251+07
1097	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-13	192.168.1.158	offline	228	75	0	2026-10-21 14:05:30.375+07	2026-10-21 14:05:30.379941+07
1098	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-20	192.168.1.157	offline	237	75	0	2026-10-21 14:05:30.375+07	2026-10-21 14:05:30.381769+07
1099	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-2	192.168.1.156	offline	220	75	0	2026-10-21 14:05:33.875+07	2026-10-21 14:05:33.880078+07
1100	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-38	192.168.1.155	offline	241	75	0	2026-10-21 14:05:33.875+07	2026-10-21 14:05:33.881908+07
1101	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-35	192.168.1.161	offline	735	75	0	2026-10-21 14:05:37.869+07	2026-10-21 14:05:37.872643+07
1102	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-33	192.168.1.126	offline	727	75	0	2026-10-21 14:05:37.869+07	2026-10-21 14:05:37.873957+07
1103	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-31	192.168.1.125	offline	234	75	0	2026-10-21 14:05:41.369+07	2026-10-21 14:05:41.373003+07
1104	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-89	192.168.1.124	offline	226	75	0	2026-10-21 14:05:41.369+07	2026-10-21 14:05:41.374426+07
1105	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-34	192.168.1.123	offline	722	75	0	2026-10-21 14:05:45.38+07	2026-10-21 14:05:45.386367+07
1106	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-93	192.168.1.122	offline	730	75	0	2026-10-21 14:05:45.38+07	2026-10-21 14:05:45.389383+07
1107	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-32	192.168.1.121	offline	226	75	0	2026-10-21 14:05:48.881+07	2026-10-21 14:05:48.885158+07
1108	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-18	192.168.1.120	offline	234	75	0	2026-10-21 14:05:48.882+07	2026-10-21 14:05:48.886577+07
1109	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-1	192.168.1.160	online	45	0	1.67	2026-10-21 14:05:49.829+07	2026-10-21 14:05:52.380549+07
1110	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-108	192.168.1.118	offline	237	75	0	2026-10-21 14:05:52.375+07	2026-10-21 14:05:52.381834+07
1111	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-42	192.168.1.117	offline	230	75	0	2026-10-21 14:05:55.872+07	2026-10-21 14:05:55.877445+07
1112	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-62	192.168.1.116	offline	238	75	0	2026-10-21 14:05:55.872+07	2026-10-21 14:05:55.880394+07
1113	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-69	192.168.1.1	online	57	0	21	2026-10-21 14:05:56.881+07	2026-10-21 14:05:59.383199+07
1114	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-59	192.168.1.114	offline	234	75	0	2026-10-21 14:05:59.376+07	2026-10-21 14:05:59.386513+07
1115	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-64	192.168.1.113	offline	229	75	0	2026-10-21 14:06:02.873+07	2026-10-21 14:06:02.87786+07
1116	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-27	192.168.1.112	offline	237	75	0	2026-10-21 14:06:02.873+07	2026-10-21 14:06:02.879679+07
1117	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-107	192.168.1.111	offline	228	75	0	2026-10-21 14:06:06.371+07	2026-10-21 14:06:06.379023+07
1118	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-97	192.168.1.110	offline	237	75	0	2026-10-21 14:06:06.371+07	2026-10-21 14:06:06.380729+07
1119	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-106	192.168.1.109	offline	235	75	0	2026-10-21 14:06:09.87+07	2026-10-21 14:06:09.874187+07
1120	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-75	192.168.1.108	offline	227	75	0	2026-10-21 14:06:09.87+07	2026-10-21 14:06:09.875595+07
1121	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-92	192.168.1.107	offline	229	75	0	2026-10-21 14:06:13.371+07	2026-10-21 14:06:13.375707+07
1122	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-70	192.168.1.106	offline	237	75	0	2026-10-21 14:06:13.371+07	2026-10-21 14:06:13.377767+07
1123	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-83	192.168.1.105	offline	241	75	0	2026-10-21 14:06:16.872+07	2026-10-21 14:06:16.876458+07
1124	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-63	192.168.1.104	offline	249	75	0	2026-10-21 14:06:16.872+07	2026-10-21 14:06:16.87877+07
1125	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-68	192.168.1.103	offline	243	75	0	2026-10-21 14:06:20.377+07	2026-10-21 14:06:20.381375+07
1126	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-78	192.168.1.102	offline	251	75	0	2026-10-21 14:06:20.377+07	2026-10-21 14:06:20.383051+07
1127	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-14	192.168.1.101	offline	228	75	0	2026-10-21 14:06:23.872+07	2026-10-21 14:06:23.877163+07
1128	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-96	192.168.1.100	offline	236	75	0	2026-10-21 14:06:23.872+07	2026-10-21 14:06:23.879341+07
1129	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-86	192.168.1.99	offline	251	75	0	2026-10-21 14:06:27.373+07	2026-10-21 14:06:27.378262+07
1130	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-94	192.168.1.98	offline	243	75	0	2026-10-21 14:06:27.373+07	2026-10-21 14:06:27.380294+07
1131	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-91	192.168.1.97	offline	239	75	0	2026-10-21 14:06:30.867+07	2026-10-21 14:06:30.870889+07
1132	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-11	192.168.1.96	offline	230	75	0	2026-10-21 14:06:30.867+07	2026-10-21 14:06:30.872249+07
1133	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-85	192.168.1.95	offline	236	75	0	2026-10-21 14:06:34.371+07	2026-10-21 14:06:34.374603+07
1134	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-41	192.168.1.94	offline	227	75	0	2026-10-21 14:06:34.371+07	2026-10-21 14:06:34.376141+07
1135	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-17	192.168.1.93	offline	229	75	0	2026-10-21 14:06:37.876+07	2026-10-21 14:06:37.882465+07
1136	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-6	192.168.1.92	offline	238	75	0	2026-10-21 14:06:37.876+07	2026-10-21 14:06:37.884172+07
1137	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-15	192.168.1.91	offline	245	75	0	2026-10-21 14:06:41.371+07	2026-10-21 14:06:41.376414+07
1138	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-49	192.168.1.90	offline	253	75	0	2026-10-21 14:06:41.371+07	2026-10-21 14:06:41.379438+07
1139	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-104	192.168.1.89	offline	238	75	0	2026-10-21 14:06:44.866+07	2026-10-21 14:06:44.870262+07
1140	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-16	192.168.1.87	offline	229	75	0	2026-10-21 14:06:44.866+07	2026-10-21 14:06:44.873511+07
1147	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-8	192.168.1.80	offline	254	75	0	2026-10-21 14:06:58.876+07	2026-10-21 14:06:58.880141+07
1148	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-103	192.168.1.79	offline	246	75	0	2026-10-21 14:06:58.875+07	2026-10-21 14:06:58.891379+07
1151	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-95	192.168.1.76	offline	228	75	0	2026-10-21 14:07:05.87+07	2026-10-21 14:07:05.873836+07
1152	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-12	192.168.1.75	offline	237	75	0	2026-10-21 14:07:05.87+07	2026-10-21 14:07:05.875642+07
1153	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-54	192.168.1.74	offline	225	75	0	2026-10-21 14:07:09.372+07	2026-10-21 14:07:09.378203+07
1154	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-5	192.168.1.73	offline	235	75	0	2026-10-21 14:07:09.372+07	2026-10-21 14:07:09.380199+07
1157	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-61	192.168.1.70	offline	235	75	0	2026-10-21 14:07:16.375+07	2026-10-21 14:07:16.38013+07
1158	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-90	192.168.1.69	offline	226	75	0	2026-10-21 14:07:16.375+07	2026-10-21 14:07:16.381601+07
1159	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-73	192.168.1.68	offline	230	75	0	2026-10-21 14:07:19.876+07	2026-10-21 14:07:19.880309+07
1160	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-67	192.168.1.67	offline	239	75	0	2026-10-21 14:07:19.876+07	2026-10-21 14:07:19.881624+07
1161	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-76	192.168.1.66	offline	225	75	0	2026-10-21 14:07:23.37+07	2026-10-21 14:07:23.373322+07
1162	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-50	192.168.1.65	offline	234	75	0	2026-10-21 14:07:23.37+07	2026-10-21 14:07:23.375036+07
1165	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-84	192.168.1.62	offline	245	75	0	2026-10-21 14:07:30.367+07	2026-10-21 14:07:30.37189+07
1166	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-29	192.168.1.61	offline	253	75	0	2026-10-21 14:07:30.367+07	2026-10-21 14:07:30.374281+07
1419	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	143	0	15	2026-10-21 18:04:54.708+07	2026-10-21 18:04:56.871699+07
1432	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	113	0	84.33	2026-10-21 18:39:39.103+07	2026-10-21 18:39:41.379446+07
1546	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	48	0	11	2026-10-21 18:45:58.347+07	2026-10-21 18:46:00.886952+07
1547	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	240	75	0	2026-10-21 18:46:00.879+07	2026-10-21 18:46:00.888834+07
1579	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	245	75	0	2026-10-21 19:03:38.382+07	2026-10-21 19:03:38.390305+07
1580	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	255	75	0	2026-10-21 19:03:38.382+07	2026-10-21 19:03:38.395965+07
1583	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	232	75	0	2026-10-21 19:03:45.378+07	2026-10-21 19:03:45.385221+07
1584	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	243	75	0	2026-10-21 19:03:45.378+07	2026-10-21 19:03:45.388368+07
1585	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	235	75	0	2026-10-21 19:03:48.878+07	2026-10-21 19:03:48.884576+07
1586	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	246	75	0	2026-10-21 19:03:48.878+07	2026-10-21 19:03:48.88661+07
1587	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	231	75	0	2026-10-21 19:03:52.381+07	2026-10-21 19:03:52.38603+07
1588	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	245	75	0	2026-10-21 19:03:52.381+07	2026-10-21 19:03:52.388169+07
1619	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	238	75	0	2026-10-21 19:18:46.88+07	2026-10-21 19:18:46.888348+07
1620	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	243	75	0	2026-10-21 19:18:46.88+07	2026-10-21 19:18:46.890709+07
1623	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	233	75	0	2026-10-21 19:18:53.878+07	2026-10-21 19:18:53.883211+07
1624	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	245	75	0	2026-10-21 19:18:53.878+07	2026-10-21 19:18:53.885045+07
1627	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	234	75	0	2026-10-21 19:19:00.882+07	2026-10-21 19:19:00.892049+07
1628	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	245	75	0	2026-10-21 19:19:00.882+07	2026-10-21 19:19:00.898276+07
1633	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	230	75	0	2026-10-21 19:19:11.375+07	2026-10-21 19:19:11.378652+07
1634	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	216	75	0	2026-10-21 19:19:11.375+07	2026-10-21 19:19:11.379995+07
1635	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	236	75	0	2026-10-21 19:19:14.881+07	2026-10-21 19:19:14.885059+07
1636	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	228	75	0	2026-10-21 19:19:14.881+07	2026-10-21 19:19:14.886464+07
1641	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	242	75	0	2026-10-21 19:19:25.379+07	2026-10-21 19:19:25.386199+07
1642	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	238	75	0	2026-10-21 19:19:25.379+07	2026-10-21 19:19:25.389282+07
1645	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	240	75	0	2026-10-21 19:19:32.379+07	2026-10-21 19:19:32.383905+07
1646	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	233	75	0	2026-10-21 19:19:32.379+07	2026-10-21 19:19:32.385439+07
1647	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	233	75	0	2026-10-21 19:19:35.882+07	2026-10-21 19:19:35.893049+07
1648	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	239	75	0	2026-10-21 19:19:35.882+07	2026-10-21 19:19:35.894447+07
1713	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	222	75	0	2026-10-21 19:24:34.87+07	2026-10-21 19:24:34.875838+07
1716	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	127	0	74.67	2026-10-21 19:33:34.651+07	2026-10-21 19:33:36.883122+07
1720	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	236	75	0	2026-10-21 19:37:02.873+07	2026-10-21 19:37:02.884616+07
1725	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 19:46:23.374+07	2026-10-21 19:46:23.380055+07
1726	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 19:46:28.376+07	2026-10-21 19:46:28.380006+07
1729	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	unknown	269	50	467	2026-10-21 19:52:38.435+07	2026-10-21 19:52:38.440913+07
1732	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-21 19:55:50.881+07	2026-10-21 19:55:50.889377+07
1734	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 19:58:54.876+07	2026-10-21 19:58:54.887885+07
1735	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 19:58:59.871+07	2026-10-21 19:58:59.878592+07
1736	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	35	75	0	2026-10-21 20:02:03.163+07	2026-10-21 20:02:03.168689+07
1737	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	242	75	0	2026-10-21 20:02:08.373+07	2026-10-21 20:02:08.377647+07
1738	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	unknown	156	50	199	2026-10-21 20:04:55.205+07	2026-10-21 20:04:55.88738+07
1739	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 20:05:17.876+07	2026-10-21 20:05:17.882272+07
1740	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-21 20:08:26.374+07	2026-10-21 20:08:26.380632+07
1141	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-60	192.168.1.86	offline	207	75	0	2026-10-21 14:06:48.38+07	2026-10-21 14:06:48.38455+07
1142	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-48	192.168.1.85	offline	234	75	0	2026-10-21 14:06:48.38+07	2026-10-21 14:06:48.386027+07
1143	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-10	192.168.1.84	offline	229	75	0	2026-10-21 14:06:51.87+07	2026-10-21 14:06:51.873764+07
1144	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-72	192.168.1.83	offline	237	75	0	2026-10-21 14:06:51.87+07	2026-10-21 14:06:51.875492+07
1145	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-74	192.168.1.82	offline	236	75	0	2026-10-21 14:06:55.372+07	2026-10-21 14:06:55.37633+07
1146	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-9	192.168.1.81	offline	228	75	0	2026-10-21 14:06:55.372+07	2026-10-21 14:06:55.378319+07
1149	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-52	192.168.1.78	offline	238	75	0	2026-10-21 14:07:02.374+07	2026-10-21 14:07:02.381074+07
1150	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-44	192.168.1.77	offline	229	75	0	2026-10-21 14:07:02.374+07	2026-10-21 14:07:02.382666+07
1155	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-114	192.168.1.72	offline	231	75	0	2026-10-21 14:07:12.867+07	2026-10-21 14:07:12.871856+07
1156	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-19	192.168.1.71	offline	239	75	0	2026-10-21 14:07:12.867+07	2026-10-21 14:07:12.873416+07
1163	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-81	192.168.1.64	offline	230	75	0	2026-10-21 14:07:26.877+07	2026-10-21 14:07:26.881689+07
1164	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-39	192.168.1.63	offline	238	75	0	2026-10-21 14:07:26.877+07	2026-10-21 14:07:26.883084+07
1167	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-53	192.168.1.60	offline	254	75	0	2026-10-21 14:07:33.872+07	2026-10-21 14:07:33.877784+07
1168	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-43	192.168.1.59	offline	246	75	0	2026-10-21 14:07:33.872+07	2026-10-21 14:07:33.880459+07
1169	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-100	192.168.1.58	offline	228	75	0	2026-10-21 14:07:37.375+07	2026-10-21 14:07:37.381706+07
1170	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-57	192.168.1.57	offline	239	75	0	2026-10-21 14:07:37.375+07	2026-10-21 14:07:37.383157+07
1171	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-109	192.168.1.56	offline	229	75	0	2026-10-21 14:07:40.87+07	2026-10-21 14:07:40.878266+07
1172	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-45	192.168.1.55	offline	238	75	0	2026-10-21 14:07:40.87+07	2026-10-21 14:07:40.879963+07
1173	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-55	192.168.1.54	offline	238	75	0	2026-10-21 14:07:44.373+07	2026-10-21 14:07:44.37799+07
1174	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-3	192.168.1.53	offline	229	75	0	2026-10-21 14:07:44.373+07	2026-10-21 14:07:44.379365+07
1175	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-111	192.168.1.52	online	45	0	3.33	2026-10-21 14:07:45.331+07	2026-10-21 14:07:47.882772+07
1176	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-36	192.168.1.51	offline	238	75	0	2026-10-21 14:07:47.879+07	2026-10-21 14:07:47.883994+07
1177	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-47	192.168.1.50	online	53	0	10.33	2026-10-21 14:07:48.871+07	2026-10-21 14:07:48.884596+07
1178	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-77	192.168.1.49	online	46	0	7	2026-10-21 14:07:48.881+07	2026-10-21 14:07:48.885809+07
1179	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-99	192.168.1.48	offline	228	75	0	2026-10-21 14:07:52.38+07	2026-10-21 14:07:52.385634+07
1180	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-26	192.168.1.47	offline	237	75	0	2026-10-21 14:07:52.38+07	2026-10-21 14:07:52.387155+07
1181	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-112	192.168.1.46	offline	253	75	0	2026-10-21 14:07:55.875+07	2026-10-21 14:07:55.881035+07
1182	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-65	192.168.1.45	offline	244	75	0	2026-10-21 14:07:55.875+07	2026-10-21 14:07:55.882692+07
1183	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-113	192.168.1.44	offline	236	75	0	2026-10-21 14:07:59.38+07	2026-10-21 14:07:59.385193+07
1184	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-88	192.168.1.43	offline	229	75	0	2026-10-21 14:07:59.38+07	2026-10-21 14:07:59.387429+07
1185	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-102	192.168.1.42	offline	253	75	0	2026-10-21 14:08:02.868+07	2026-10-21 14:08:02.876214+07
1186	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-7	192.168.1.41	offline	244	75	0	2026-10-21 14:08:02.868+07	2026-10-21 14:08:02.878301+07
1187	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-82	192.168.1.40	offline	236	75	0	2026-10-21 14:08:06.378+07	2026-10-21 14:08:06.381773+07
1188	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-51	192.168.1.39	offline	226	75	0	2026-10-21 14:08:06.378+07	2026-10-21 14:08:06.383122+07
1189	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-24	192.168.1.38	offline	227	75	0	2026-10-21 14:08:09.871+07	2026-10-21 14:08:09.876061+07
1190	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-25	192.168.1.37	offline	236	75	0	2026-10-21 14:08:09.871+07	2026-10-21 14:08:09.877392+07
1191	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-56	192.168.1.36	offline	242	75	0	2026-10-21 14:08:13.368+07	2026-10-21 14:08:13.371851+07
1192	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-87	192.168.1.15	offline	253	75	0	2026-10-21 14:08:13.368+07	2026-10-21 14:08:13.373474+07
1193	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-58	192.168.1.14	offline	236	75	0	2026-10-21 14:08:16.876+07	2026-10-21 14:08:16.881576+07
1194	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-105	192.168.1.13	offline	227	75	0	2026-10-21 14:08:16.876+07	2026-10-21 14:08:16.884673+07
1195	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-101	192.168.1.12	offline	236	75	0	2026-10-21 14:08:20.367+07	2026-10-21 14:08:20.370457+07
1196	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-79	192.168.1.11	offline	227	75	0	2026-10-21 14:08:20.367+07	2026-10-21 14:08:20.371747+07
1197	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-98	192.168.1.10	offline	238	75	0	2026-10-21 14:08:23.869+07	2026-10-21 14:08:23.874277+07
1198	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-66	192.168.1.9	offline	229	75	0	2026-10-21 14:08:23.869+07	2026-10-21 14:08:23.876546+07
1199	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-80	192.168.1.8	offline	229	75	0	2026-10-21 14:08:27.37+07	2026-10-21 14:08:27.374149+07
1200	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-4	192.168.1.7	offline	237	75	0	2026-10-21 14:08:27.37+07	2026-10-21 14:08:27.376187+07
1201	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-30	192.168.1.6	online	46	0	4.67	2026-10-21 14:08:28.33+07	2026-10-21 14:08:28.350009+07
1202	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-21	192.168.1.5	online	47	0	3	2026-10-21 14:08:28.346+07	2026-10-21 14:08:28.351368+07
1203	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-28	192.168.1.4	online	48	0	13	2026-10-21 14:08:29.325+07	2026-10-21 14:08:31.881274+07
1204	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-23	192.168.1.3	offline	240	75	0	2026-10-21 14:08:31.877+07	2026-10-21 14:08:31.882865+07
1205	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-46	192.168.1.2	online	46	0	4	2026-10-21 14:08:32.84+07	2026-10-21 14:08:35.374999+07
1206	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-22	192.168.1.135	offline	237	75	0	2026-10-21 14:08:35.37+07	2026-10-21 14:08:35.377019+07
1207	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-37	192.168.1.0	offline	229	75	0	2026-10-21 14:08:38.88+07	2026-10-21 14:08:38.886207+07
1208	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-branch-40	192.168.1.16	offline	238	75	0	2026-10-21 14:08:38.879+07	2026-10-21 14:08:38.887814+07
1209	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 14:11:50.882+07	2026-10-21 14:11:50.895234+07
1210	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	242	75	0	2026-10-21 14:14:59.873+07	2026-10-21 14:14:59.88079+07
1211	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 14:18:08.882+07	2026-10-21 14:18:08.894287+07
1212	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 14:21:17.381+07	2026-10-21 14:21:17.393312+07
1213	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	226	75	0	2026-10-21 14:24:26.374+07	2026-10-21 14:24:26.388244+07
1214	agent-e91d0d63-f134-42dd-b121-a066cab212f6	hnth-hub	192.168.1.169	offline	245	75	0	2026-10-21 14:27:35.885+07	2026-10-21 14:27:35.899529+07
1215	agent-demo	hnth-hub	192.168.1.169	offline	232	75	0	2026-10-21 14:29:46.881+07	2026-10-21 14:29:46.886646+07
1216	agent-demo	hnth-branch-110	192.168.1.159	offline	236	75	0	2026-10-21 14:29:46.881+07	2026-10-21 14:29:46.888315+07
1217	agent-demo	hnth-branch-13	192.168.1.158	offline	238	75	0	2026-10-21 14:29:50.379+07	2026-10-21 14:29:50.384911+07
1218	agent-demo	hnth-branch-20	192.168.1.157	offline	231	75	0	2026-10-21 14:29:50.379+07	2026-10-21 14:29:50.386545+07
1219	agent-demo	hnth-branch-2	192.168.1.156	offline	240	75	0	2026-10-21 14:29:53.882+07	2026-10-21 14:29:53.888323+07
1220	agent-demo	hnth-branch-38	192.168.1.155	offline	234	75	0	2026-10-21 14:29:53.882+07	2026-10-21 14:29:53.89079+07
1221	agent-demo	hnth-branch-35	192.168.1.161	offline	241	75	0	2026-10-21 14:29:57.379+07	2026-10-21 14:29:57.383402+07
1222	agent-demo	hnth-branch-33	192.168.1.126	offline	236	75	0	2026-10-21 14:29:57.379+07	2026-10-21 14:29:57.385277+07
1223	agent-demo	hnth-branch-31	192.168.1.125	offline	249	75	0	2026-10-21 14:30:00.878+07	2026-10-21 14:30:00.88752+07
1224	agent-demo	hnth-branch-89	192.168.1.124	offline	252	75	0	2026-10-21 14:30:00.878+07	2026-10-21 14:30:00.890739+07
1225	agent-demo	hnth-branch-34	192.168.1.123	offline	234	75	0	2026-10-21 14:30:04.366+07	2026-10-21 14:30:04.371658+07
1226	agent-demo	hnth-branch-93	192.168.1.122	offline	241	75	0	2026-10-21 14:30:04.366+07	2026-10-21 14:30:04.373241+07
1227	agent-demo	hnth-branch-32	192.168.1.121	offline	241	75	0	2026-10-21 14:30:07.872+07	2026-10-21 14:30:07.876257+07
1228	agent-demo	hnth-branch-18	192.168.1.120	offline	236	75	0	2026-10-21 14:30:07.872+07	2026-10-21 14:30:07.878561+07
1229	agent-demo	hnth-branch-1	192.168.1.160	online	42	0	12.67	2026-10-21 14:30:08.827+07	2026-10-21 14:30:11.371838+07
1230	agent-demo	hnth-branch-108	192.168.1.118	offline	238	75	0	2026-10-21 14:30:11.368+07	2026-10-21 14:30:11.373164+07
1231	agent-demo	hnth-branch-42	192.168.1.117	offline	235	75	0	2026-10-21 14:30:14.869+07	2026-10-21 14:30:14.873321+07
1232	agent-demo	hnth-branch-62	192.168.1.116	offline	238	75	0	2026-10-21 14:30:14.869+07	2026-10-21 14:30:14.874779+07
1233	agent-demo	hnth-branch-69	192.168.1.1	online	40	0	11.67	2026-10-21 14:30:15.823+07	2026-10-21 14:30:18.375843+07
1234	agent-demo	hnth-branch-59	192.168.1.114	offline	235	75	0	2026-10-21 14:30:18.371+07	2026-10-21 14:30:18.377793+07
1235	agent-demo	hnth-branch-64	192.168.1.113	offline	232	75	0	2026-10-21 14:30:21.87+07	2026-10-21 14:30:21.874555+07
1236	agent-demo	hnth-branch-27	192.168.1.112	offline	237	75	0	2026-10-21 14:30:21.87+07	2026-10-21 14:30:21.876984+07
1237	agent-demo	hnth-branch-107	192.168.1.111	offline	238	75	0	2026-10-21 14:30:25.374+07	2026-10-21 14:30:25.38199+07
1238	agent-demo	hnth-branch-97	192.168.1.110	offline	234	75	0	2026-10-21 14:30:25.374+07	2026-10-21 14:30:25.383662+07
1239	agent-demo	hnth-branch-106	192.168.1.109	offline	234	75	0	2026-10-21 14:30:28.869+07	2026-10-21 14:30:28.873221+07
1240	agent-demo	hnth-branch-75	192.168.1.108	offline	239	75	0	2026-10-21 14:30:28.869+07	2026-10-21 14:30:28.874735+07
1241	agent-demo	hnth-branch-92	192.168.1.107	offline	222	75	0	2026-10-21 14:30:32.374+07	2026-10-21 14:30:32.379723+07
1242	agent-demo	hnth-branch-70	192.168.1.106	offline	219	75	0	2026-10-21 14:30:32.374+07	2026-10-21 14:30:32.381078+07
1243	agent-demo	hnth-branch-83	192.168.1.105	offline	238	75	0	2026-10-21 14:30:35.873+07	2026-10-21 14:30:35.877768+07
1244	agent-demo	hnth-branch-63	192.168.1.104	offline	234	75	0	2026-10-21 14:30:35.873+07	2026-10-21 14:30:35.87939+07
1245	agent-demo	hnth-branch-68	192.168.1.103	offline	231	75	0	2026-10-21 14:30:39.366+07	2026-10-21 14:30:39.369537+07
1246	agent-demo	hnth-branch-78	192.168.1.102	offline	235	75	0	2026-10-21 14:30:39.366+07	2026-10-21 14:30:39.370923+07
1247	agent-demo	hnth-branch-14	192.168.1.101	offline	235	75	0	2026-10-21 14:30:42.866+07	2026-10-21 14:30:42.869948+07
1248	agent-demo	hnth-branch-96	192.168.1.100	offline	232	75	0	2026-10-21 14:30:42.866+07	2026-10-21 14:30:42.871299+07
1249	agent-demo	hnth-branch-86	192.168.1.99	offline	250	75	0	2026-10-21 14:30:46.374+07	2026-10-21 14:30:46.378049+07
1250	agent-demo	hnth-branch-94	192.168.1.98	offline	243	75	0	2026-10-21 14:30:46.374+07	2026-10-21 14:30:46.37966+07
1420	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 18:05:10.867+07	2026-10-21 18:05:10.874383+07
1433	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	242	75	0	2026-10-21 18:39:55.385+07	2026-10-21 18:39:55.39187+07
1550	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	247	75	0	2026-10-21 18:49:14.875+07	2026-10-21 18:49:14.883291+07
1589	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	245	75	0	2026-10-21 19:03:55.88+07	2026-10-21 19:03:55.885867+07
1590	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	235	75	0	2026-10-21 19:03:55.88+07	2026-10-21 19:03:55.887515+07
1595	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	224	75	0	2026-10-21 19:04:06.368+07	2026-10-21 19:04:06.371791+07
1596	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	216	75	0	2026-10-21 19:04:06.368+07	2026-10-21 19:04:06.373066+07
1631	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	239	75	0	2026-10-21 19:19:07.879+07	2026-10-21 19:19:07.88983+07
1632	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	244	75	0	2026-10-21 19:19:07.879+07	2026-10-21 19:19:07.892156+07
1637	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	239	75	0	2026-10-21 19:19:18.367+07	2026-10-21 19:19:18.370495+07
1638	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	245	75	0	2026-10-21 19:19:18.367+07	2026-10-21 19:19:18.371893+07
1639	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	226	75	0	2026-10-21 19:19:21.877+07	2026-10-21 19:19:21.882478+07
1640	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	237	75	0	2026-10-21 19:19:21.877+07	2026-10-21 19:19:21.884281+07
1643	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	241	75	0	2026-10-21 19:19:28.879+07	2026-10-21 19:19:28.882409+07
1644	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	230	75	0	2026-10-21 19:19:28.879+07	2026-10-21 19:19:28.883753+07
1649	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	241	75	0	2026-10-21 19:19:39.385+07	2026-10-21 19:19:39.399432+07
1650	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	236	75	0	2026-10-21 19:19:39.385+07	2026-10-21 19:19:39.402557+07
1657	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	243	75	0	2026-10-21 19:19:53.374+07	2026-10-21 19:19:53.386276+07
1658	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	254	75	0	2026-10-21 19:19:53.374+07	2026-10-21 19:19:53.387659+07
1661	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	225	75	0	2026-10-21 19:20:00.368+07	2026-10-21 19:20:00.373565+07
1662	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	237	75	0	2026-10-21 19:20:00.369+07	2026-10-21 19:20:00.375466+07
1663	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	226	75	0	2026-10-21 19:20:03.875+07	2026-10-21 19:20:03.879618+07
1664	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	237	75	0	2026-10-21 19:20:03.875+07	2026-10-21 19:20:03.881032+07
1665	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	234	75	0	2026-10-21 19:20:07.377+07	2026-10-21 19:20:07.385589+07
1666	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	239	75	0	2026-10-21 19:20:07.377+07	2026-10-21 19:20:07.388726+07
1669	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	237	75	0	2026-10-21 19:20:14.38+07	2026-10-21 19:20:14.384671+07
1670	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	231	75	0	2026-10-21 19:20:14.38+07	2026-10-21 19:20:14.386131+07
1671	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	228	75	0	2026-10-21 19:20:17.879+07	2026-10-21 19:20:17.888697+07
1741	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	103	75	0	2026-10-21 20:11:29.875+07	2026-10-21 20:11:29.881914+07
1742	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 20:11:34.88+07	2026-10-21 20:11:34.8863+07
1743	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	250	75	0	2026-10-21 20:14:44.88+07	2026-10-21 20:14:44.886653+07
1744	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	135	0	24	2026-10-21 20:17:30.195+07	2026-10-21 20:17:32.397893+07
1745	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 20:17:54.37+07	2026-10-21 20:17:54.376718+07
1746	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	unknown	84	25	69.5	2026-10-21 20:20:56.423+07	2026-10-21 20:20:56.428538+07
1747	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 20:21:01.38+07	2026-10-21 20:21:01.881401+07
1748	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	104	0	38.33	2026-10-21 20:24:03.408+07	2026-10-21 20:24:03.416134+07
1749	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 20:24:08.373+07	2026-10-21 20:24:08.379053+07
1750	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-21 20:27:15.38+07	2026-10-21 20:27:15.39296+07
1751	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	online	39	0	4	2026-10-21 20:30:03.808+07	2026-10-21 20:30:06.890593+07
1752	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 20:30:19.376+07	2026-10-21 20:30:19.380574+07
1753	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 20:30:24.371+07	2026-10-21 20:30:24.377176+07
1754	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	249	75	0	2026-10-21 20:33:31.382+07	2026-10-21 20:33:31.387909+07
1755	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	36	0	6.67	2026-10-21 20:36:20.312+07	2026-10-21 20:36:22.875015+07
1756	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	233	75	0	2026-10-21 20:36:37.873+07	2026-10-21 20:36:37.879666+07
1757	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 20:39:44.373+07	2026-10-21 20:39:44.379658+07
1758	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 20:42:50.874+07	2026-10-21 20:42:50.881359+07
1759	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	37	0	2.67	2026-10-21 20:45:35.81+07	2026-10-21 20:45:38.39126+07
1760	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 20:45:56.88+07	2026-10-21 20:45:56.884354+07
1761	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 20:49:00.872+07	2026-10-21 20:49:00.880495+07
1762	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 20:52:01.367+07	2026-10-21 20:52:01.375158+07
1763	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	236	75	0	2026-10-21 20:52:07.884+07	2026-10-21 20:52:07.892276+07
1764	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	123	0	39.33	2026-10-21 20:54:53.645+07	2026-10-21 20:54:55.880189+07
1765	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	245	75	0	2026-10-21 20:55:14.871+07	2026-10-21 20:55:14.877903+07
1766	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 20:58:14.872+07	2026-10-21 20:58:14.879488+07
1767	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	234	75	0	2026-10-21 20:58:21.365+07	2026-10-21 20:58:21.37224+07
1768	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	236	75	0	2026-10-21 21:01:28.37+07	2026-10-21 21:01:28.38159+07
1769	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	243	75	0	2026-10-21 21:04:35.376+07	2026-10-21 21:04:35.391102+07
1770	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 21:07:42.383+07	2026-10-21 21:07:42.389666+07
1771	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	228	75	0	2026-10-21 21:10:53.87+07	2026-10-21 21:10:53.878759+07
1772	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-21 21:14:04.372+07	2026-10-21 21:14:04.378903+07
1773	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 21:17:11.371+07	2026-10-21 21:17:11.381073+07
1774	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	234	75	0	2026-10-21 21:20:18.378+07	2026-10-21 21:20:18.385096+07
1775	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 22:16:24.871+07	2026-10-21 22:16:24.877624+07
1776	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	244	75	0	2026-10-21 22:16:24.871+07	2026-10-21 22:16:24.879463+07
1777	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	240	75	0	2026-10-21 22:16:28.367+07	2026-10-21 22:16:28.371943+07
1778	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	227	75	0	2026-10-21 22:16:28.367+07	2026-10-21 22:16:28.373698+07
1779	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	228	75	0	2026-10-21 22:16:31.884+07	2026-10-21 22:16:31.894052+07
1780	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	219	75	0	2026-10-21 22:16:31.884+07	2026-10-21 22:16:31.897328+07
1781	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	225	75	0	2026-10-21 22:16:35.379+07	2026-10-21 22:16:35.384945+07
1782	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	214	75	0	2026-10-21 22:16:35.379+07	2026-10-21 22:16:35.386405+07
1783	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	242	75	0	2026-10-21 22:16:38.868+07	2026-10-21 22:16:38.871999+07
1784	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	230	75	0	2026-10-21 22:16:38.868+07	2026-10-21 22:16:38.873625+07
1785	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	239	75	0	2026-10-21 22:16:42.379+07	2026-10-21 22:16:42.384429+07
1786	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	229	75	0	2026-10-21 22:16:42.379+07	2026-10-21 22:16:42.386117+07
1787	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	232	75	0	2026-10-21 22:16:45.871+07	2026-10-21 22:16:45.876085+07
1788	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	244	75	0	2026-10-21 22:16:45.871+07	2026-10-21 22:16:45.878191+07
1789	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	65	0	39.67	2026-10-21 22:16:46.92+07	2026-10-21 22:16:49.372526+07
1790	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	236	75	0	2026-10-21 22:16:49.369+07	2026-10-21 22:16:49.373888+07
1791	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	244	75	0	2026-10-21 22:16:52.866+07	2026-10-21 22:16:52.871082+07
1792	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	232	75	0	2026-10-21 22:16:52.866+07	2026-10-21 22:16:52.87296+07
1793	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	57	0	21.33	2026-10-21 22:16:53.888+07	2026-10-21 22:16:56.390344+07
1794	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	234	75	0	2026-10-21 22:16:56.382+07	2026-10-21 22:16:56.393406+07
1795	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	228	75	0	2026-10-21 22:16:59.885+07	2026-10-21 22:16:59.892143+07
1796	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	241	75	0	2026-10-21 22:16:59.885+07	2026-10-21 22:16:59.895229+07
1797	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	255	75	0	2026-10-21 22:17:03.368+07	2026-10-21 22:17:03.371933+07
1798	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	257	75	0	2026-10-21 22:17:03.368+07	2026-10-21 22:17:03.373226+07
1799	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	239	75	0	2026-10-21 22:17:06.871+07	2026-10-21 22:17:06.875763+07
1800	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	225	75	0	2026-10-21 22:17:06.871+07	2026-10-21 22:17:06.877191+07
1801	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	240	75	0	2026-10-21 22:17:10.375+07	2026-10-21 22:17:10.379923+07
1802	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	235	75	0	2026-10-21 22:17:10.375+07	2026-10-21 22:17:10.381867+07
1807	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	235	75	0	2026-10-21 22:17:20.88+07	2026-10-21 22:17:20.88454+07
1808	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	238	75	0	2026-10-21 22:17:20.88+07	2026-10-21 22:17:20.885982+07
1809	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	237	75	0	2026-10-21 22:17:24.375+07	2026-10-21 22:17:24.382198+07
1810	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	233	75	0	2026-10-21 22:17:24.375+07	2026-10-21 22:17:24.384433+07
1813	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	239	75	0	2026-10-21 22:17:31.366+07	2026-10-21 22:17:31.369884+07
1814	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	234	75	0	2026-10-21 22:17:31.366+07	2026-10-21 22:17:31.37128+07
1819	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	242	75	0	2026-10-21 22:17:41.871+07	2026-10-21 22:17:41.878584+07
1820	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	232	75	0	2026-10-21 22:17:41.871+07	2026-10-21 22:17:41.882174+07
2793	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	238	75	0	2026-10-22 00:13:57.88+07	2026-10-22 00:13:57.889412+07
2794	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	227	75	0	2026-10-22 00:13:57.88+07	2026-10-22 00:13:57.891888+07
2799	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	214	75	0	2026-10-22 00:14:08.373+07	2026-10-22 00:14:08.376869+07
2800	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	226	75	0	2026-10-22 00:14:08.373+07	2026-10-22 00:14:08.378377+07
2982	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-22 00:34:15.375+07	2026-10-22 00:34:15.382658+07
2983	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	253	75	0	2026-10-22 00:34:46.386+07	2026-10-22 00:34:46.395607+07
2984	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	244	75	0	2026-10-22 00:34:46.385+07	2026-10-22 00:34:46.400583+07
2987	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	246	75	0	2026-10-22 00:34:51.88+07	2026-10-22 00:34:51.888827+07
2988	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	235	75	0	2026-10-22 00:34:51.88+07	2026-10-22 00:34:51.893868+07
3106	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	744	75	0	2026-10-22 00:48:15.868+07	2026-10-22 00:48:15.876592+07
3107	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	755	75	0	2026-10-22 00:48:15.868+07	2026-10-22 00:48:15.879737+07
3110	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	247	75	0	2026-10-22 00:48:23.389+07	2026-10-22 00:48:23.403395+07
3111	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	259	75	0	2026-10-22 00:48:23.389+07	2026-10-22 00:48:23.410477+07
3114	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	721	75	0	2026-10-22 00:48:31.377+07	2026-10-22 00:48:31.388961+07
3115	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	732	75	0	2026-10-22 00:48:31.377+07	2026-10-22 00:48:31.394937+07
3118	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	61	0	41	2026-10-22 00:48:36.422+07	2026-10-22 00:48:39.395024+07
3119	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	739	75	0	2026-10-22 00:48:39.385+07	2026-10-22 00:48:39.39818+07
3122	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	72	0	17	2026-10-22 00:48:44.471+07	2026-10-22 00:48:47.379199+07
3123	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	732	75	0	2026-10-22 00:48:47.374+07	2026-10-22 00:48:47.38111+07
3140	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	235	75	0	2026-10-22 00:49:20.873+07	2026-10-22 00:49:20.884719+07
3141	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	202	75	0	2026-10-22 00:49:20.873+07	2026-10-22 00:49:20.891463+07
3219	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-22 00:54:42.871+07	2026-10-22 00:54:42.879045+07
3227	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-22 01:13:37.875+07	2026-10-22 01:13:37.914435+07
3290	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	232	75	0	2026-10-22 01:16:42.883+07	2026-10-22 01:16:42.889869+07
3291	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	238	75	0	2026-10-22 01:16:42.883+07	2026-10-22 01:16:42.893577+07
3292	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	230	75	0	2026-10-22 01:16:46.371+07	2026-10-22 01:16:46.376141+07
3293	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	220	75	0	2026-10-22 01:16:46.371+07	2026-10-22 01:16:46.378238+07
3338	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	42	0	8	2026-10-22 01:18:01.902+07	2026-10-22 01:18:04.413479+07
3339	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	240	75	0	2026-10-22 01:18:04.409+07	2026-10-22 01:18:04.415299+07
3340	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	47	0	10.67	2026-10-22 01:18:05.369+07	2026-10-22 01:18:07.918548+07
3341	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	237	75	0	2026-10-22 01:18:07.908+07	2026-10-22 01:18:07.920204+07
3342	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	237	75	0	2026-10-22 01:18:11.409+07	2026-10-22 01:18:11.413661+07
3343	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	240	75	0	2026-10-22 01:18:11.41+07	2026-10-22 01:18:11.415156+07
3345	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	240	75	0	2026-10-22 01:23:34.909+07	2026-10-22 01:23:34.914531+07
3346	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	236	75	0	2026-10-22 01:23:34.909+07	2026-10-22 01:23:34.924768+07
3349	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	230	75	0	2026-10-22 01:23:40.413+07	2026-10-22 01:23:40.420254+07
3350	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	242	75	0	2026-10-22 01:23:40.412+07	2026-10-22 01:23:40.424048+07
3355	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	240	75	0	2026-10-22 01:23:50.913+07	2026-10-22 01:23:50.919795+07
3356	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	234	75	0	2026-10-22 01:23:50.912+07	2026-10-22 01:23:50.923278+07
3357	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	234	75	0	2026-10-22 01:23:54.405+07	2026-10-22 01:23:54.41371+07
3358	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	245	75	0	2026-10-22 01:23:54.405+07	2026-10-22 01:23:54.418848+07
3360	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	242	75	0	2026-10-22 01:23:57.915+07	2026-10-22 01:23:57.930974+07
3361	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	73	0	25	2026-10-22 01:23:58.993+07	2026-10-22 01:24:01.412493+07
3362	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	240	75	0	2026-10-22 01:24:01.407+07	2026-10-22 01:24:01.41501+07
3363	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	244	75	0	2026-10-22 01:24:04.912+07	2026-10-22 01:24:04.91732+07
3364	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	235	75	0	2026-10-22 01:24:04.912+07	2026-10-22 01:24:04.918936+07
3365	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	65	0	22	2026-10-22 01:24:05.956+07	2026-10-22 01:24:08.423097+07
1803	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	240	75	0	2026-10-21 22:17:13.87+07	2026-10-21 22:17:13.874709+07
1804	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	236	75	0	2026-10-21 22:17:13.87+07	2026-10-21 22:17:13.87646+07
1805	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	233	75	0	2026-10-21 22:17:17.373+07	2026-10-21 22:17:17.378094+07
1806	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	223	75	0	2026-10-21 22:17:17.373+07	2026-10-21 22:17:17.38037+07
1811	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	241	75	0	2026-10-21 22:17:27.876+07	2026-10-21 22:17:27.88795+07
1812	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	229	75	0	2026-10-21 22:17:27.876+07	2026-10-21 22:17:27.891344+07
1815	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	230	75	0	2026-10-21 22:17:34.882+07	2026-10-21 22:17:34.886479+07
1816	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	236	75	0	2026-10-21 22:17:34.882+07	2026-10-21 22:17:34.888026+07
1817	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	225	75	0	2026-10-21 22:17:38.372+07	2026-10-21 22:17:38.37624+07
1818	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	239	75	0	2026-10-21 22:17:38.372+07	2026-10-21 22:17:38.377595+07
1821	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	226	75	0	2026-10-21 22:17:45.379+07	2026-10-21 22:17:45.38391+07
1822	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	240	75	0	2026-10-21 22:17:45.379+07	2026-10-21 22:17:45.385362+07
1823	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	232	75	0	2026-10-21 22:17:48.874+07	2026-10-21 22:17:48.877982+07
1824	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	246	75	0	2026-10-21 22:17:48.874+07	2026-10-21 22:17:48.880086+07
1825	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	236	75	0	2026-10-21 22:17:52.376+07	2026-10-21 22:17:52.381461+07
1826	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	224	75	0	2026-10-21 22:17:52.376+07	2026-10-21 22:17:52.383398+07
1827	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	233	75	0	2026-10-21 22:17:55.874+07	2026-10-21 22:17:55.880854+07
1828	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	244	75	0	2026-10-21 22:17:55.874+07	2026-10-21 22:17:55.882948+07
1829	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	234	75	0	2026-10-21 22:17:59.376+07	2026-10-21 22:17:59.384201+07
1830	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	244	75	0	2026-10-21 22:17:59.375+07	2026-10-21 22:17:59.386752+07
1831	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	233	75	0	2026-10-21 22:18:02.873+07	2026-10-21 22:18:02.877311+07
1832	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	241	75	0	2026-10-21 22:18:02.873+07	2026-10-21 22:18:02.879012+07
1833	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	232	75	0	2026-10-21 22:18:06.369+07	2026-10-21 22:18:06.373133+07
1834	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	240	75	0	2026-10-21 22:18:06.369+07	2026-10-21 22:18:06.374543+07
1835	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	234	75	0	2026-10-21 22:18:09.875+07	2026-10-21 22:18:09.879918+07
1836	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	238	75	0	2026-10-21 22:18:09.875+07	2026-10-21 22:18:09.882017+07
1837	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	218	75	0	2026-10-21 22:18:13.372+07	2026-10-21 22:18:13.375956+07
1838	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	223	75	0	2026-10-21 22:18:13.372+07	2026-10-21 22:18:13.377423+07
1839	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	237	75	0	2026-10-21 22:18:16.866+07	2026-10-21 22:18:16.869805+07
1840	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	232	75	0	2026-10-21 22:18:16.866+07	2026-10-21 22:18:16.871203+07
1841	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	242	75	0	2026-10-21 22:18:20.378+07	2026-10-21 22:18:20.382831+07
1842	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	232	75	0	2026-10-21 22:18:20.378+07	2026-10-21 22:18:20.384335+07
1843	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	235	75	0	2026-10-21 22:18:23.871+07	2026-10-21 22:18:23.876287+07
1844	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	240	75	0	2026-10-21 22:18:23.871+07	2026-10-21 22:18:23.877926+07
1845	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-21 22:19:19.381+07	2026-10-21 22:19:19.387967+07
1846	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	228	75	0	2026-10-21 22:19:19.381+07	2026-10-21 22:19:19.390897+07
1847	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	243	75	0	2026-10-21 22:19:22.88+07	2026-10-21 22:19:22.895167+07
1848	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	236	75	0	2026-10-21 22:19:22.881+07	2026-10-21 22:19:22.89915+07
1849	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	245	75	0	2026-10-21 22:19:26.381+07	2026-10-21 22:19:26.385757+07
1850	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	233	75	0	2026-10-21 22:19:26.381+07	2026-10-21 22:19:26.387814+07
1851	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	229	75	0	2026-10-21 22:19:29.879+07	2026-10-21 22:19:29.885225+07
1852	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	242	75	0	2026-10-21 22:19:29.879+07	2026-10-21 22:19:29.887568+07
1853	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	226	75	0	2026-10-21 22:19:33.371+07	2026-10-21 22:19:33.375582+07
1854	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	237	75	0	2026-10-21 22:19:33.371+07	2026-10-21 22:19:33.377418+07
1855	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	235	75	0	2026-10-21 22:19:36.881+07	2026-10-21 22:19:36.88845+07
1856	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	247	75	0	2026-10-21 22:19:36.881+07	2026-10-21 22:19:36.891858+07
1857	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	236	75	0	2026-10-21 22:19:40.37+07	2026-10-21 22:19:40.374124+07
1858	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	226	75	0	2026-10-21 22:19:40.37+07	2026-10-21 22:19:40.375709+07
1859	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	66	0	28	2026-10-21 22:19:41.412+07	2026-10-21 22:19:43.895511+07
1860	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	238	75	0	2026-10-21 22:19:43.885+07	2026-10-21 22:19:43.901704+07
1861	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	232	75	0	2026-10-21 22:19:47.376+07	2026-10-21 22:19:47.383919+07
1862	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	243	75	0	2026-10-21 22:19:47.376+07	2026-10-21 22:19:47.387474+07
1863	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	62	0	19.67	2026-10-21 22:19:48.416+07	2026-10-21 22:19:50.882606+07
1864	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	239	75	0	2026-10-21 22:19:50.873+07	2026-10-21 22:19:50.886808+07
1865	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	245	75	0	2026-10-21 22:19:54.377+07	2026-10-21 22:19:54.385073+07
1866	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	233	75	0	2026-10-21 22:19:54.377+07	2026-10-21 22:19:54.387672+07
1867	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	245	75	0	2026-10-21 22:19:57.88+07	2026-10-21 22:19:57.884574+07
1868	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	240	75	0	2026-10-21 22:19:57.88+07	2026-10-21 22:19:57.886018+07
1869	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	224	75	0	2026-10-21 22:20:01.375+07	2026-10-21 22:20:01.380772+07
1870	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	231	75	0	2026-10-21 22:20:01.375+07	2026-10-21 22:20:01.382767+07
1873	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	233	75	0	2026-10-21 22:20:08.371+07	2026-10-21 22:20:08.375086+07
1874	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	240	75	0	2026-10-21 22:20:08.371+07	2026-10-21 22:20:08.376883+07
1877	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	242	75	0	2026-10-21 22:20:15.381+07	2026-10-21 22:20:15.38467+07
1878	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	238	75	0	2026-10-21 22:20:15.381+07	2026-10-21 22:20:15.38598+07
1881	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	246	75	0	2026-10-21 22:20:22.383+07	2026-10-21 22:20:22.387898+07
1882	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	234	75	0	2026-10-21 22:20:22.383+07	2026-10-21 22:20:22.389256+07
1883	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	229	75	0	2026-10-21 22:20:25.872+07	2026-10-21 22:20:25.879582+07
1884	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	243	75	0	2026-10-21 22:20:25.872+07	2026-10-21 22:20:25.883181+07
1887	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	242	75	0	2026-10-21 22:20:32.883+07	2026-10-21 22:20:32.890282+07
1888	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	234	75	0	2026-10-21 22:20:32.883+07	2026-10-21 22:20:32.89424+07
1893	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	247	75	0	2026-10-21 22:20:43.377+07	2026-10-21 22:20:43.381445+07
1894	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	238	75	0	2026-10-21 22:20:43.377+07	2026-10-21 22:20:43.382786+07
1901	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	245	75	0	2026-10-21 22:20:57.375+07	2026-10-21 22:20:57.379979+07
1902	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	236	75	0	2026-10-21 22:20:57.375+07	2026-10-21 22:20:57.381864+07
1905	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	228	75	0	2026-10-21 22:21:04.371+07	2026-10-21 22:21:04.37527+07
1906	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	218	75	0	2026-10-21 22:21:04.371+07	2026-10-21 22:21:04.376983+07
1907	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	225	75	0	2026-10-21 22:21:07.871+07	2026-10-21 22:21:07.880156+07
1908	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	213	75	0	2026-10-21 22:21:07.872+07	2026-10-21 22:21:07.884244+07
2795	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	237	75	0	2026-10-22 00:14:01.367+07	2026-10-22 00:14:01.372614+07
2796	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	245	75	0	2026-10-22 00:14:01.367+07	2026-10-22 00:14:01.374439+07
2797	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	232	75	0	2026-10-22 00:14:04.88+07	2026-10-22 00:14:04.888311+07
2798	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	239	75	0	2026-10-22 00:14:04.881+07	2026-10-22 00:14:04.892128+07
2803	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	238	75	0	2026-10-22 00:14:15.376+07	2026-10-22 00:14:15.380674+07
2804	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	230	75	0	2026-10-22 00:14:15.376+07	2026-10-22 00:14:15.382895+07
2805	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	230	75	0	2026-10-22 00:14:18.87+07	2026-10-22 00:14:18.877343+07
2806	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	242	75	0	2026-10-22 00:14:18.87+07	2026-10-22 00:14:18.881794+07
2807	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	227	75	0	2026-10-22 00:14:22.368+07	2026-10-22 00:14:22.372149+07
2808	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	239	75	0	2026-10-22 00:14:22.368+07	2026-10-22 00:14:22.373987+07
2811	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	244	75	0	2026-10-22 00:14:29.367+07	2026-10-22 00:14:29.372029+07
2812	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	232	75	0	2026-10-22 00:14:29.367+07	2026-10-22 00:14:29.374089+07
2813	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	230	75	0	2026-10-22 00:14:32.875+07	2026-10-22 00:14:32.879732+07
2814	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	241	75	0	2026-10-22 00:14:32.875+07	2026-10-22 00:14:32.882324+07
2819	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	229	75	0	2026-10-22 00:14:43.381+07	2026-10-22 00:14:43.385231+07
2820	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	240	75	0	2026-10-22 00:14:43.381+07	2026-10-22 00:14:43.386801+07
2821	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	243	75	0	2026-10-22 00:14:46.876+07	2026-10-22 00:14:46.885912+07
2822	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	232	75	0	2026-10-22 00:14:46.876+07	2026-10-22 00:14:46.890046+07
2823	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	225	75	0	2026-10-22 00:14:50.376+07	2026-10-22 00:14:50.380481+07
2824	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	238	75	0	2026-10-22 00:14:50.376+07	2026-10-22 00:14:50.382559+07
2825	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	231	75	0	2026-10-22 00:14:53.884+07	2026-10-22 00:14:53.891241+07
2826	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	241	75	0	2026-10-22 00:14:53.884+07	2026-10-22 00:14:53.894891+07
2831	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	44	0	14.67	2026-10-22 00:15:01.85+07	2026-10-22 00:15:04.385297+07
2832	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	239	75	0	2026-10-22 00:15:04.381+07	2026-10-22 00:15:04.386998+07
2833	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	55	0	22.67	2026-10-22 00:15:05.384+07	2026-10-22 00:15:05.390863+07
2834	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	47	0	20.33	2026-10-22 00:15:05.387+07	2026-10-22 00:15:05.392384+07
2835	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	234	75	0	2026-10-22 00:15:08.88+07	2026-10-22 00:15:08.884868+07
2836	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	240	75	0	2026-10-22 00:15:08.88+07	2026-10-22 00:15:08.886933+07
2841	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	240	75	0	2026-10-22 00:15:19.379+07	2026-10-22 00:15:19.383788+07
2842	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	235	75	0	2026-10-22 00:15:19.379+07	2026-10-22 00:15:19.385162+07
2845	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	227	75	0	2026-10-22 00:15:26.371+07	2026-10-22 00:15:26.375149+07
2846	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	219	75	0	2026-10-22 00:15:26.371+07	2026-10-22 00:15:26.376613+07
2847	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	241	75	0	2026-10-22 00:15:29.875+07	2026-10-22 00:15:29.884207+07
2848	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	229	75	0	2026-10-22 00:15:29.876+07	2026-10-22 00:15:29.889792+07
2851	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	243	75	0	2026-10-22 00:15:36.882+07	2026-10-22 00:15:37.384325+07
2852	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 00:15:37.38+07	2026-10-22 00:15:37.385786+07
2859	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	55	0	17.33	2026-10-22 00:15:46.847+07	2026-10-22 00:15:49.378756+07
2860	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	237	75	0	2026-10-22 00:15:49.374+07	2026-10-22 00:15:49.380896+07
1871	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	253	75	0	2026-10-21 22:20:04.874+07	2026-10-21 22:20:04.885255+07
1872	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	248	75	0	2026-10-21 22:20:04.874+07	2026-10-21 22:20:04.888935+07
1875	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	236	75	0	2026-10-21 22:20:11.878+07	2026-10-21 22:20:11.88443+07
1876	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	232	75	0	2026-10-21 22:20:11.878+07	2026-10-21 22:20:11.886798+07
1879	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	230	75	0	2026-10-21 22:20:18.877+07	2026-10-21 22:20:18.882896+07
1880	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	245	75	0	2026-10-21 22:20:18.877+07	2026-10-21 22:20:18.885113+07
1885	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	239	75	0	2026-10-21 22:20:29.367+07	2026-10-21 22:20:29.371088+07
1886	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	230	75	0	2026-10-21 22:20:29.367+07	2026-10-21 22:20:29.372551+07
1889	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	245	75	0	2026-10-21 22:20:36.377+07	2026-10-21 22:20:36.381326+07
1890	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	234	75	0	2026-10-21 22:20:36.376+07	2026-10-21 22:20:36.383093+07
1891	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	231	75	0	2026-10-21 22:20:39.88+07	2026-10-21 22:20:39.890293+07
1892	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	243	75	0	2026-10-21 22:20:39.88+07	2026-10-21 22:20:39.895263+07
1895	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	249	75	0	2026-10-21 22:20:46.878+07	2026-10-21 22:20:46.88702+07
1896	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	237	75	0	2026-10-21 22:20:46.878+07	2026-10-21 22:20:46.890804+07
1897	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	233	75	0	2026-10-21 22:20:50.377+07	2026-10-21 22:20:50.381627+07
1898	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	244	75	0	2026-10-21 22:20:50.377+07	2026-10-21 22:20:50.383148+07
1899	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	206	75	0	2026-10-21 22:20:53.882+07	2026-10-21 22:20:53.892354+07
1900	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	247	75	0	2026-10-21 22:20:53.881+07	2026-10-21 22:20:53.896519+07
1903	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	237	75	0	2026-10-21 22:21:00.885+07	2026-10-21 22:21:00.89828+07
1904	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	245	75	0	2026-10-21 22:21:00.886+07	2026-10-21 22:21:00.903576+07
1909	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	236	75	0	2026-10-21 22:21:11.375+07	2026-10-21 22:21:11.37984+07
1910	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	224	75	0	2026-10-21 22:21:11.375+07	2026-10-21 22:21:11.381487+07
1911	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	229	75	0	2026-10-21 22:21:14.872+07	2026-10-21 22:21:14.890724+07
1912	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	242	75	0	2026-10-21 22:21:14.873+07	2026-10-21 22:21:14.895831+07
1913	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	239	75	0	2026-10-21 22:21:18.38+07	2026-10-21 22:21:18.38448+07
1914	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	235	75	0	2026-10-21 22:21:18.38+07	2026-10-21 22:21:18.386711+07
1915	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	218	75	0	2026-10-21 22:28:32.887+07	2026-10-21 22:28:32.902695+07
1916	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	229	75	0	2026-10-21 22:28:32.887+07	2026-10-21 22:28:32.928514+07
1917	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	257	75	0	2026-10-21 22:28:36.384+07	2026-10-21 22:28:36.392866+07
1918	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	251	75	0	2026-10-21 22:28:36.384+07	2026-10-21 22:28:36.395792+07
1919	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	241	75	0	2026-10-21 22:28:39.868+07	2026-10-21 22:28:39.872134+07
1920	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	230	75	0	2026-10-21 22:28:39.868+07	2026-10-21 22:28:39.873701+07
1921	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	219	75	0	2026-10-21 22:28:43.378+07	2026-10-21 22:28:43.382253+07
1922	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	240	75	0	2026-10-21 22:28:43.378+07	2026-10-21 22:28:43.384596+07
1923	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	234	75	0	2026-10-21 22:28:46.877+07	2026-10-21 22:28:46.891659+07
1924	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	244	75	0	2026-10-21 22:28:46.877+07	2026-10-21 22:28:46.894597+07
1925	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	235	75	0	2026-10-21 22:28:50.381+07	2026-10-21 22:28:50.392506+07
1926	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	243	75	0	2026-10-21 22:28:50.381+07	2026-10-21 22:28:50.397733+07
1927	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	232	75	0	2026-10-21 22:28:53.879+07	2026-10-21 22:28:53.887319+07
1928	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	240	75	0	2026-10-21 22:28:53.879+07	2026-10-21 22:28:53.88868+07
1929	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	38	0	12.67	2026-10-21 22:28:54.823+07	2026-10-21 22:28:57.381472+07
1930	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	241	75	0	2026-10-21 22:28:57.368+07	2026-10-21 22:28:57.384585+07
1931	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	242	75	0	2026-10-21 22:29:00.883+07	2026-10-21 22:29:00.890758+07
1932	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	235	75	0	2026-10-21 22:29:00.883+07	2026-10-21 22:29:00.892514+07
1933	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	39	0	9	2026-10-21 22:29:01.823+07	2026-10-21 22:29:04.383049+07
1934	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	236	75	0	2026-10-21 22:29:04.375+07	2026-10-21 22:29:04.384606+07
1935	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	246	75	0	2026-10-21 22:29:07.876+07	2026-10-21 22:29:07.880396+07
1936	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	242	75	0	2026-10-21 22:29:07.876+07	2026-10-21 22:29:07.881956+07
1937	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	238	75	0	2026-10-21 22:29:11.378+07	2026-10-21 22:29:11.382529+07
1938	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	227	75	0	2026-10-21 22:29:11.378+07	2026-10-21 22:29:11.383967+07
1939	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	234	75	0	2026-10-21 22:29:14.875+07	2026-10-21 22:29:14.879655+07
1940	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	240	75	0	2026-10-21 22:29:14.875+07	2026-10-21 22:29:14.881307+07
1941	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	239	75	0	2026-10-21 22:29:18.371+07	2026-10-21 22:29:18.376308+07
1942	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	228	75	0	2026-10-21 22:29:18.371+07	2026-10-21 22:29:18.37819+07
1943	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	235	75	0	2026-10-21 22:29:21.877+07	2026-10-21 22:29:21.887102+07
1944	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	228	75	0	2026-10-21 22:29:21.877+07	2026-10-21 22:29:21.891679+07
1945	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	236	75	0	2026-10-21 22:29:25.37+07	2026-10-21 22:29:25.378023+07
1946	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	232	75	0	2026-10-21 22:29:25.37+07	2026-10-21 22:29:25.382472+07
1947	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	237	75	0	2026-10-21 22:29:28.872+07	2026-10-21 22:29:28.882557+07
1948	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	230	75	0	2026-10-21 22:29:28.872+07	2026-10-21 22:29:28.887709+07
1951	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	235	75	0	2026-10-21 22:29:35.87+07	2026-10-21 22:29:35.874861+07
1952	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	239	75	0	2026-10-21 22:29:35.87+07	2026-10-21 22:29:35.876525+07
1953	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	239	75	0	2026-10-21 22:29:39.382+07	2026-10-21 22:29:39.386659+07
1954	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	234	75	0	2026-10-21 22:29:39.382+07	2026-10-21 22:29:39.388243+07
1955	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	237	75	0	2026-10-21 22:29:42.87+07	2026-10-21 22:29:42.875167+07
1956	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	233	75	0	2026-10-21 22:29:42.87+07	2026-10-21 22:29:42.876962+07
1963	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	242	75	0	2026-10-21 22:29:56.873+07	2026-10-21 22:29:56.880602+07
1964	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	232	75	0	2026-10-21 22:29:56.872+07	2026-10-21 22:29:56.883687+07
1967	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	243	75	0	2026-10-21 22:30:03.872+07	2026-10-21 22:30:03.87829+07
1968	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	230	75	0	2026-10-21 22:30:03.873+07	2026-10-21 22:30:03.881251+07
1969	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	245	75	0	2026-10-21 22:30:07.374+07	2026-10-21 22:30:07.384739+07
1970	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	243	75	0	2026-10-21 22:30:07.375+07	2026-10-21 22:30:07.388423+07
1973	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	234	75	0	2026-10-21 22:30:14.37+07	2026-10-21 22:30:14.374518+07
1974	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	239	75	0	2026-10-21 22:30:14.37+07	2026-10-21 22:30:14.375964+07
1975	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	233	75	0	2026-10-21 22:30:17.877+07	2026-10-21 22:30:17.886761+07
1976	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	238	75	0	2026-10-21 22:30:17.877+07	2026-10-21 22:30:17.891073+07
1977	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	218	75	0	2026-10-21 22:30:21.371+07	2026-10-21 22:30:21.375105+07
1978	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	227	75	0	2026-10-21 22:30:21.371+07	2026-10-21 22:30:21.376753+07
1983	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	250	75	0	2026-10-21 22:30:31.879+07	2026-10-21 22:30:31.888287+07
1984	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	262	75	0	2026-10-21 22:30:31.879+07	2026-10-21 22:30:31.892041+07
1985	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	234	75	0	2026-10-21 22:30:35.368+07	2026-10-21 22:30:35.372518+07
1986	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	237	75	0	2026-10-21 22:30:35.368+07	2026-10-21 22:30:35.373961+07
1989	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	257	75	0	2026-10-21 22:30:42.381+07	2026-10-21 22:30:42.385929+07
1990	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	251	75	0	2026-10-21 22:30:42.381+07	2026-10-21 22:30:42.387674+07
1993	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	226	75	0	2026-10-21 22:30:49.387+07	2026-10-21 22:30:49.401189+07
1994	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	238	75	0	2026-10-21 22:30:49.387+07	2026-10-21 22:30:49.406239+07
1995	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	74	0	14	2026-10-21 22:30:50.49+07	2026-10-21 22:30:52.876264+07
1996	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	220	75	0	2026-10-21 22:30:52.872+07	2026-10-21 22:30:52.878245+07
1999	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	237	75	0	2026-10-21 22:30:57.377+07	2026-10-21 22:30:57.386571+07
2000	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	233	75	0	2026-10-21 22:30:57.379+07	2026-10-21 22:30:57.39001+07
2801	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	223	75	0	2026-10-22 00:14:11.872+07	2026-10-22 00:14:11.884206+07
2802	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	228	75	0	2026-10-22 00:14:11.872+07	2026-10-22 00:14:11.888647+07
2809	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	231	75	0	2026-10-22 00:14:25.882+07	2026-10-22 00:14:25.889739+07
2810	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	241	75	0	2026-10-22 00:14:25.882+07	2026-10-22 00:14:25.893218+07
2815	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	241	75	0	2026-10-22 00:14:36.381+07	2026-10-22 00:14:36.385146+07
2816	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	229	75	0	2026-10-22 00:14:36.381+07	2026-10-22 00:14:36.386639+07
2817	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	233	75	0	2026-10-22 00:14:39.885+07	2026-10-22 00:14:39.894657+07
2818	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	244	75	0	2026-10-22 00:14:39.885+07	2026-10-22 00:14:39.900026+07
2827	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	234	75	0	2026-10-22 00:14:57.373+07	2026-10-22 00:14:57.376864+07
2828	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	240	75	0	2026-10-22 00:14:57.373+07	2026-10-22 00:14:57.378297+07
2829	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	239	75	0	2026-10-22 00:15:00.877+07	2026-10-22 00:15:00.882624+07
2830	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	233	75	0	2026-10-22 00:15:00.877+07	2026-10-22 00:15:00.884894+07
2837	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	241	75	0	2026-10-22 00:15:12.375+07	2026-10-22 00:15:12.379739+07
2838	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	237	75	0	2026-10-22 00:15:12.375+07	2026-10-22 00:15:12.381722+07
2839	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	254	75	0	2026-10-22 00:15:15.875+07	2026-10-22 00:15:15.880246+07
2840	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	261	75	0	2026-10-22 00:15:15.875+07	2026-10-22 00:15:15.882011+07
2843	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	236	75	0	2026-10-22 00:15:22.88+07	2026-10-22 00:15:22.885162+07
2844	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	245	75	0	2026-10-22 00:15:22.88+07	2026-10-22 00:15:22.887056+07
2849	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	211	75	0	2026-10-22 00:15:33.368+07	2026-10-22 00:15:33.37163+07
2850	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	224	75	0	2026-10-22 00:15:33.367+07	2026-10-22 00:15:33.373079+07
2853	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	241	75	0	2026-10-22 00:15:40.876+07	2026-10-22 00:15:40.884166+07
2854	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	237	75	0	2026-10-22 00:15:40.876+07	2026-10-22 00:15:40.888371+07
2855	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 00:15:44.881+07	2026-10-22 00:15:44.88671+07
2856	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	50	0	12.67	2026-10-22 00:15:41.875+07	2026-10-22 00:15:44.889332+07
2857	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	45	0	7	2026-10-22 00:15:45.84+07	2026-10-22 00:15:45.847098+07
2858	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	41	0	3	2026-10-22 00:15:45.842+07	2026-10-22 00:15:45.848831+07
1949	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	204	75	0	2026-10-21 22:29:32.389+07	2026-10-21 22:29:32.401802+07
1950	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	208	75	0	2026-10-21 22:29:32.389+07	2026-10-21 22:29:32.407309+07
1957	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	234	75	0	2026-10-21 22:29:46.369+07	2026-10-21 22:29:46.37428+07
1958	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	238	75	0	2026-10-21 22:29:46.369+07	2026-10-21 22:29:46.37621+07
1959	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	236	75	0	2026-10-21 22:29:49.879+07	2026-10-21 22:29:49.886706+07
1960	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	241	75	0	2026-10-21 22:29:49.879+07	2026-10-21 22:29:49.889773+07
1961	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	244	75	0	2026-10-21 22:29:53.37+07	2026-10-21 22:29:53.37395+07
1962	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	234	75	0	2026-10-21 22:29:53.37+07	2026-10-21 22:29:53.375304+07
1965	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	248	75	0	2026-10-21 22:30:00.367+07	2026-10-21 22:30:00.372438+07
1966	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	260	75	0	2026-10-21 22:30:00.367+07	2026-10-21 22:30:00.374463+07
1971	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	240	75	0	2026-10-21 22:30:10.872+07	2026-10-21 22:30:10.8797+07
1972	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	231	75	0	2026-10-21 22:30:10.872+07	2026-10-21 22:30:10.884552+07
1979	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	230	75	0	2026-10-21 22:30:24.872+07	2026-10-21 22:30:24.877201+07
1980	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	240	75	0	2026-10-21 22:30:24.872+07	2026-10-21 22:30:24.880189+07
1981	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	259	75	0	2026-10-21 22:30:28.372+07	2026-10-21 22:30:28.378452+07
1982	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	247	75	0	2026-10-21 22:30:28.372+07	2026-10-21 22:30:28.381401+07
1987	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	230	75	0	2026-10-21 22:30:38.868+07	2026-10-21 22:30:38.878053+07
1988	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	241	75	0	2026-10-21 22:30:38.868+07	2026-10-21 22:30:38.88159+07
1991	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	243	75	0	2026-10-21 22:30:45.884+07	2026-10-21 22:30:45.889972+07
1992	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	231	75	0	2026-10-21 22:30:45.884+07	2026-10-21 22:30:45.892498+07
1997	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	39	0	4.67	2026-10-21 22:30:53.815+07	2026-10-21 22:30:53.824489+07
1998	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	39	0	4.33	2026-10-21 22:30:53.82+07	2026-10-21 22:30:53.826019+07
2001	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	232	75	0	2026-10-21 22:31:00.871+07	2026-10-21 22:31:00.888437+07
2002	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	241	75	0	2026-10-21 22:31:00.871+07	2026-10-21 22:31:00.893012+07
2003	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	244	75	0	2026-10-21 22:31:04.386+07	2026-10-21 22:31:04.39834+07
2004	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	235	75	0	2026-10-21 22:31:04.387+07	2026-10-21 22:31:04.402965+07
2005	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	248	75	0	2026-10-21 22:31:07.879+07	2026-10-21 22:31:07.889459+07
2006	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	256	75	0	2026-10-21 22:31:07.879+07	2026-10-21 22:31:07.89429+07
2007	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	241	75	0	2026-10-21 22:31:11.38+07	2026-10-21 22:31:11.389694+07
2008	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	254	75	0	2026-10-21 22:31:11.381+07	2026-10-21 22:31:11.393463+07
2009	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	240	75	0	2026-10-21 22:31:14.88+07	2026-10-21 22:31:14.887543+07
2010	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	237	75	0	2026-10-21 22:31:14.88+07	2026-10-21 22:31:14.891093+07
2011	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	234	75	0	2026-10-21 22:31:18.377+07	2026-10-21 22:31:18.384621+07
2012	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	244	75	0	2026-10-21 22:31:18.376+07	2026-10-21 22:31:18.387755+07
2013	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	236	75	0	2026-10-21 22:31:21.872+07	2026-10-21 22:31:21.878849+07
2014	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	241	75	0	2026-10-21 22:31:21.871+07	2026-10-21 22:31:21.881297+07
2015	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	240	75	0	2026-10-21 22:31:25.377+07	2026-10-21 22:31:25.871857+07
2016	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 22:31:25.867+07	2026-10-21 22:31:25.873563+07
2017	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	240	75	0	2026-10-21 22:31:29.377+07	2026-10-21 22:31:29.387776+07
2018	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	229	75	0	2026-10-21 22:31:29.377+07	2026-10-21 22:31:29.392505+07
2019	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	online	125	0	39.67	2026-10-21 22:31:30.681+07	2026-10-21 22:31:33.379561+07
2020	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 22:31:33.372+07	2026-10-21 22:31:33.382399+07
2021	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	58	0	9.67	2026-10-21 22:31:34.399+07	2026-10-21 22:31:34.403187+07
2022	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	53	0	6.67	2026-10-21 22:31:34.397+07	2026-10-21 22:31:34.404766+07
2023	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	69	0	8	2026-10-21 22:31:35.456+07	2026-10-21 22:31:37.8819+07
2024	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	227	75	0	2026-10-21 22:31:37.877+07	2026-10-21 22:31:37.883562+07
2025	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	56	0	43	2026-10-21 22:31:38.886+07	2026-10-21 22:31:41.381103+07
2026	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	238	75	0	2026-10-21 22:31:41.374+07	2026-10-21 22:31:41.384612+07
2027	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	228	75	0	2026-10-21 22:31:44.872+07	2026-10-21 22:31:44.879361+07
2028	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	216	75	0	2026-10-21 22:31:44.872+07	2026-10-21 22:31:44.882648+07
2029	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-21 22:34:55.876+07	2026-10-21 22:34:55.887491+07
2030	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	145	0	8	2026-10-21 22:37:45.245+07	2026-10-21 22:37:47.379258+07
2031	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-21 22:38:02.881+07	2026-10-21 22:38:02.896854+07
2032	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-21 22:41:42.371+07	2026-10-21 22:41:43.044007+07
2033	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	239	75	0	2026-10-21 22:41:41.879+07	2026-10-21 22:41:43.397526+07
2034	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	255	75	0	2026-10-21 22:41:46.878+07	2026-10-21 22:41:47.259145+07
2035	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	246	75	0	2026-10-21 22:41:46.877+07	2026-10-21 22:41:47.603245+07
2036	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	237	75	0	2026-10-21 22:41:50.881+07	2026-10-21 22:41:50.927201+07
2037	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	233	75	0	2026-10-21 22:41:50.881+07	2026-10-21 22:41:51.258532+07
2040	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	254	75	0	2026-10-21 22:42:05.376+07	2026-10-21 22:42:06.366814+07
2041	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	242	75	0	2026-10-21 22:42:05.869+07	2026-10-21 22:42:06.929696+07
2044	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	238	75	0	2026-10-21 22:42:14.366+07	2026-10-21 22:42:14.659718+07
2045	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	233	75	0	2026-10-21 22:42:14.366+07	2026-10-21 22:42:14.990653+07
2861	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	43	0	19.33	2026-10-22 00:15:50.333+07	2026-10-22 00:15:52.885967+07
2862	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	243	75	0	2026-10-22 00:15:52.879+07	2026-10-22 00:15:52.88916+07
2985	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	717	75	0	2026-10-22 00:34:48.375+07	2026-10-22 00:34:48.382379+07
2986	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	728	75	0	2026-10-22 00:34:48.376+07	2026-10-22 00:34:48.384953+07
2989	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	731	75	0	2026-10-22 00:34:55.882+07	2026-10-22 00:34:55.890321+07
2990	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	744	75	0	2026-10-22 00:34:55.882+07	2026-10-22 00:34:55.893999+07
2993	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	721	75	0	2026-10-22 00:35:03.873+07	2026-10-22 00:35:03.883306+07
2994	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	731	75	0	2026-10-22 00:35:03.873+07	2026-10-22 00:35:03.888423+07
2997	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	730	75	0	2026-10-22 00:35:11.878+07	2026-10-22 00:35:11.882365+07
2998	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	738	75	0	2026-10-22 00:35:11.878+07	2026-10-22 00:35:11.884331+07
3124	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	743	75	0	2026-10-22 00:48:51.38+07	2026-10-22 00:48:51.38776+07
3125	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	739	75	0	2026-10-22 00:48:51.38+07	2026-10-22 00:48:51.389611+07
3128	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	728	75	0	2026-10-22 00:48:59.378+07	2026-10-22 00:48:59.38356+07
3129	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	742	75	0	2026-10-22 00:48:59.376+07	2026-10-22 00:48:59.386008+07
3136	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	236	75	0	2026-10-22 00:49:13.881+07	2026-10-22 00:49:13.88519+07
3137	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	242	75	0	2026-10-22 00:49:13.881+07	2026-10-22 00:49:13.88672+07
3142	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	223	75	0	2026-10-22 00:49:24.376+07	2026-10-22 00:49:24.381248+07
3143	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	237	75	0	2026-10-22 00:49:24.376+07	2026-10-22 00:49:24.383761+07
3150	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	228	75	0	2026-10-22 00:49:38.382+07	2026-10-22 00:49:38.387041+07
3151	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	239	75	0	2026-10-22 00:49:38.382+07	2026-10-22 00:49:38.389879+07
3164	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	237	75	0	2026-10-22 00:50:02.877+07	2026-10-22 00:50:02.884248+07
3165	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	225	75	0	2026-10-22 00:50:02.877+07	2026-10-22 00:50:02.885944+07
3220	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	233	75	0	2026-10-22 00:57:52.888+07	2026-10-22 00:57:52.906385+07
3228	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-22 01:14:57.893+07	2026-10-22 01:14:57.910567+07
3230	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	249	75	0	2026-10-22 01:14:57.893+07	2026-10-22 01:14:57.916663+07
3232	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	261	75	0	2026-10-22 01:15:01.376+07	2026-10-22 01:15:01.383088+07
3233	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	250	75	0	2026-10-22 01:15:01.375+07	2026-10-22 01:15:01.386567+07
3236	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	239	75	0	2026-10-22 01:15:08.369+07	2026-10-22 01:15:08.375131+07
3237	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	227	75	0	2026-10-22 01:15:08.369+07	2026-10-22 01:15:08.377616+07
3300	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	239	75	0	2026-10-22 01:17:00.367+07	2026-10-22 01:17:00.373486+07
3301	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	229	75	0	2026-10-22 01:17:00.367+07	2026-10-22 01:17:00.385143+07
3302	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	241	75	0	2026-10-22 01:17:03.878+07	2026-10-22 01:17:03.886341+07
3303	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	237	75	0	2026-10-22 01:17:03.879+07	2026-10-22 01:17:03.889918+07
3310	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	36	0	3	2026-10-22 01:17:15.296+07	2026-10-22 01:17:17.874744+07
3311	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	237	75	0	2026-10-22 01:17:17.87+07	2026-10-22 01:17:17.877264+07
3316	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	244	75	0	2026-10-22 01:17:25.881+07	2026-10-22 01:17:25.891318+07
3317	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	239	75	0	2026-10-22 01:17:25.882+07	2026-10-22 01:17:25.895793+07
3320	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	235	75	0	2026-10-22 01:17:32.878+07	2026-10-22 01:17:32.886249+07
3321	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	238	75	0	2026-10-22 01:17:32.878+07	2026-10-22 01:17:32.890101+07
3324	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	232	75	0	2026-10-22 01:17:39.873+07	2026-10-22 01:17:41.411987+07
3325	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	236	75	0	2026-10-22 01:17:39.873+07	2026-10-22 01:17:41.41339+07
3334	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 01:17:59.901+07	2026-10-22 01:17:59.906129+07
3335	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	40	0	3.67	2026-10-22 01:17:56.844+07	2026-10-22 01:17:59.910586+07
3336	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	61	0	33.33	2026-10-22 01:18:00.947+07	2026-10-22 01:18:00.955247+07
3337	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	62	0	35.67	2026-10-22 01:18:00.951+07	2026-10-22 01:18:00.958349+07
3344	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-22 01:21:22.416+07	2026-10-22 01:21:22.430462+07
3347	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	230	75	0	2026-10-22 01:23:36.913+07	2026-10-22 01:23:36.929672+07
3348	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	241	75	0	2026-10-22 01:23:36.913+07	2026-10-22 01:23:36.934974+07
3351	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	245	75	0	2026-10-22 01:23:43.906+07	2026-10-22 01:23:43.911106+07
3352	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	190	75	0	2026-10-22 01:23:43.906+07	2026-10-22 01:23:43.91353+07
3353	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	242	75	0	2026-10-22 01:23:47.411+07	2026-10-22 01:23:47.41925+07
3354	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	231	75	0	2026-10-22 01:23:47.411+07	2026-10-22 01:23:47.423026+07
3359	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	231	75	0	2026-10-22 01:23:57.916+07	2026-10-22 01:23:57.92603+07
2038	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	235	75	0	2026-10-21 22:42:01.379+07	2026-10-21 22:42:01.577307+07
2039	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	230	75	0	2026-10-21 22:42:00.876+07	2026-10-21 22:42:01.940751+07
2042	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	238	75	0	2026-10-21 22:42:10.384+07	2026-10-21 22:42:10.519433+07
2043	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	230	75	0	2026-10-21 22:42:10.384+07	2026-10-21 22:42:10.853108+07
2046	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	98	0	63	2026-10-21 22:42:16.173+07	2026-10-21 22:42:18.448637+07
2047	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	243	75	0	2026-10-21 22:42:18.376+07	2026-10-21 22:42:18.626808+07
2048	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	236	75	0	2026-10-21 22:42:21.88+07	2026-10-21 22:42:22.19298+07
2049	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	241	75	0	2026-10-21 22:42:21.88+07	2026-10-21 22:42:22.548234+07
2050	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	80	0	15.67	2026-10-21 22:42:23.726+07	2026-10-21 22:42:25.935336+07
2051	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	239	75	0	2026-10-21 22:42:25.874+07	2026-10-21 22:42:26.273474+07
2052	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	233	75	0	2026-10-21 22:42:29.373+07	2026-10-21 22:42:29.424754+07
2053	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	238	75	0	2026-10-21 22:42:29.373+07	2026-10-21 22:42:29.601593+07
2054	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	229	75	0	2026-10-21 22:42:32.877+07	2026-10-21 22:42:32.905732+07
2055	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	241	75	0	2026-10-21 22:42:32.877+07	2026-10-21 22:42:32.934257+07
2056	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	\N	100	0	2026-10-21 22:42:37.365+07	2026-10-21 22:42:37.736869+07
2057	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	\N	100	0	2026-10-21 22:42:37.365+07	2026-10-21 22:42:38.074739+07
2058	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	209	75	0	2026-10-21 22:42:41.878+07	2026-10-21 22:42:42.018163+07
2059	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	\N	100	0	2026-10-21 22:42:41.878+07	2026-10-21 22:42:42.366663+07
2060	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	236	75	0	2026-10-21 22:42:45.877+07	2026-10-21 22:42:46.032898+07
2061	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	242	75	0	2026-10-21 22:42:45.878+07	2026-10-21 22:42:46.225845+07
2062	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	235	75	0	2026-10-21 22:42:49.881+07	2026-10-21 22:42:49.971768+07
2063	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	243	75	0	2026-10-21 22:42:49.881+07	2026-10-21 22:42:50.315085+07
2064	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	230	75	0	2026-10-21 22:42:53.879+07	2026-10-21 22:42:54.106795+07
2065	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	237	75	0	2026-10-21 22:42:53.879+07	2026-10-21 22:42:54.109532+07
2066	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	\N	100	0	2026-10-21 22:42:58.372+07	2026-10-21 22:42:58.430355+07
2067	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	\N	100	0	2026-10-21 22:42:58.372+07	2026-10-21 22:42:58.945235+07
2068	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	245	75	0	2026-10-21 22:43:02.883+07	2026-10-21 22:43:02.971285+07
2069	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	237	75	0	2026-10-21 22:43:02.883+07	2026-10-21 22:43:03.249077+07
2070	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	231	75	0	2026-10-21 22:43:06.879+07	2026-10-21 22:43:06.965332+07
2071	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	239	75	0	2026-10-21 22:43:06.879+07	2026-10-21 22:43:07.102423+07
2072	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	245	75	0	2026-10-21 22:43:10.366+07	2026-10-21 22:43:10.530402+07
2073	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	239	75	0	2026-10-21 22:43:10.366+07	2026-10-21 22:43:10.53408+07
2074	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	243	75	0	2026-10-21 22:43:13.885+07	2026-10-21 22:43:13.943083+07
2075	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	235	75	0	2026-10-21 22:43:13.886+07	2026-10-21 22:43:14.12216+07
2076	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	236	75	0	2026-10-21 22:43:17.381+07	2026-10-21 22:43:17.528018+07
2077	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	247	75	0	2026-10-21 22:43:17.381+07	2026-10-21 22:43:17.702697+07
2078	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	239	75	0	2026-10-21 22:43:21.386+07	2026-10-21 22:43:21.46205+07
2079	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	228	75	0	2026-10-21 22:43:21.386+07	2026-10-21 22:43:21.605213+07
2080	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	239	75	0	2026-10-21 22:43:24.872+07	2026-10-21 22:43:25.096955+07
2081	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	244	75	0	2026-10-21 22:43:24.872+07	2026-10-21 22:43:25.372713+07
2082	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	236	75	0	2026-10-21 22:43:28.901+07	2026-10-21 22:43:28.931798+07
2083	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	213	75	0	2026-10-21 22:43:28.902+07	2026-10-21 22:43:28.935334+07
2084	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	236	75	0	2026-10-21 22:43:32.368+07	2026-10-21 22:43:32.512812+07
2085	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	226	75	0	2026-10-21 22:43:32.368+07	2026-10-21 22:43:32.651128+07
2086	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	237	75	0	2026-10-21 22:43:36.383+07	2026-10-21 22:43:36.670636+07
2087	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	242	75	0	2026-10-21 22:43:36.383+07	2026-10-21 22:43:37.021182+07
2088	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	241	75	0	2026-10-21 22:43:40.39+07	2026-10-21 22:43:40.397289+07
2089	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	238	75	0	2026-10-21 22:43:40.389+07	2026-10-21 22:43:40.400482+07
2090	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	242	75	0	2026-10-21 22:43:43.882+07	2026-10-21 22:43:44.295928+07
2091	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	234	75	0	2026-10-21 22:43:43.882+07	2026-10-21 22:43:44.64392+07
2092	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	240	75	0	2026-10-21 22:43:48.37+07	2026-10-21 22:43:48.611414+07
2093	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	233	75	0	2026-10-21 22:43:48.371+07	2026-10-21 22:43:48.795527+07
2094	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	227	75	0	2026-10-21 22:43:52.371+07	2026-10-21 22:43:52.524825+07
2095	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	238	75	0	2026-10-21 22:43:52.371+07	2026-10-21 22:43:52.529558+07
2096	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	225	75	0	2026-10-21 22:43:55.882+07	2026-10-21 22:43:56.195778+07
2097	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	230	75	0	2026-10-21 22:43:55.882+07	2026-10-21 22:43:56.476396+07
2098	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	216	75	0	2026-10-21 22:43:59.869+07	2026-10-21 22:43:59.929143+07
2099	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	240	75	0	2026-10-21 22:43:59.869+07	2026-10-21 22:44:00.095232+07
2100	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	217	75	0	2026-10-21 22:44:03.382+07	2026-10-21 22:44:03.406743+07
2101	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	222	75	0	2026-10-21 22:44:03.382+07	2026-10-21 22:44:03.57443+07
2863	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	252	75	0	2026-10-22 00:15:56.37+07	2026-10-22 00:15:56.373429+07
2864	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	248	75	0	2026-10-22 00:15:56.37+07	2026-10-22 00:15:56.374918+07
2991	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	727	75	0	2026-10-22 00:34:59.869+07	2026-10-22 00:34:59.87686+07
2992	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	739	75	0	2026-10-22 00:34:59.869+07	2026-10-22 00:34:59.87901+07
2995	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	717	75	0	2026-10-22 00:35:07.872+07	2026-10-22 00:35:07.881221+07
2996	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	728	75	0	2026-10-22 00:35:07.872+07	2026-10-22 00:35:07.88641+07
2999	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	52	0	25	2026-10-22 00:35:12.864+07	2026-10-22 00:35:15.879743+07
3000	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	737	75	0	2026-10-22 00:35:15.875+07	2026-10-22 00:35:15.882053+07
3001	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	725	75	0	2026-10-22 00:35:19.87+07	2026-10-22 00:35:19.874112+07
3002	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	737	75	0	2026-10-22 00:35:19.87+07	2026-10-22 00:35:19.875834+07
3005	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	742	75	0	2026-10-22 00:35:27.883+07	2026-10-22 00:35:27.89297+07
3006	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	736	75	0	2026-10-22 00:35:27.883+07	2026-10-22 00:35:27.896311+07
3011	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	231	75	0	2026-10-22 00:35:38.379+07	2026-10-22 00:35:38.387234+07
3012	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	235	75	0	2026-10-22 00:35:38.379+07	2026-10-22 00:35:38.390817+07
3023	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	237	75	0	2026-10-22 00:35:59.378+07	2026-10-22 00:35:59.389222+07
3024	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	245	75	0	2026-10-22 00:35:59.38+07	2026-10-22 00:35:59.392548+07
3130	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	740	75	0	2026-10-22 00:49:03.376+07	2026-10-22 00:49:03.383805+07
3131	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	733	75	0	2026-10-22 00:49:03.376+07	2026-10-22 00:49:03.385765+07
3134	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	236	75	0	2026-10-22 00:49:10.374+07	2026-10-22 00:49:10.378827+07
3135	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	227	75	0	2026-10-22 00:49:10.374+07	2026-10-22 00:49:10.38127+07
3144	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	242	75	0	2026-10-22 00:49:27.868+07	2026-10-22 00:49:27.872297+07
3145	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	238	75	0	2026-10-22 00:49:27.868+07	2026-10-22 00:49:27.873889+07
3148	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	226	75	0	2026-10-22 00:49:34.882+07	2026-10-22 00:49:34.887903+07
3149	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	238	75	0	2026-10-22 00:49:34.882+07	2026-10-22 00:49:34.890589+07
3154	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	250	75	0	2026-10-22 00:49:45.371+07	2026-10-22 00:49:45.375348+07
3155	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	254	75	0	2026-10-22 00:49:45.371+07	2026-10-22 00:49:45.376833+07
3221	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	82	0	56.67	2026-10-22 01:00:45.974+07	2026-10-22 01:00:48.392376+07
3229	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	234	75	0	2026-10-22 01:14:57.895+07	2026-10-22 01:14:57.913699+07
3231	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	206	75	0	2026-10-22 01:14:57.895+07	2026-10-22 01:14:57.920149+07
3234	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	227	75	0	2026-10-22 01:15:04.871+07	2026-10-22 01:15:04.87493+07
3235	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	222	75	0	2026-10-22 01:15:04.871+07	2026-10-22 01:15:04.876534+07
3240	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	239	75	0	2026-10-22 01:15:15.38+07	2026-10-22 01:15:15.390036+07
3241	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	226	75	0	2026-10-22 01:15:15.38+07	2026-10-22 01:15:15.395639+07
3246	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	243	75	0	2026-10-22 01:15:25.878+07	2026-10-22 01:15:25.888923+07
3247	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	239	75	0	2026-10-22 01:15:25.878+07	2026-10-22 01:15:25.894181+07
3250	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	244	75	0	2026-10-22 01:15:32.885+07	2026-10-22 01:15:32.892739+07
3251	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	238	75	0	2026-10-22 01:15:32.885+07	2026-10-22 01:15:32.896911+07
3254	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	245	75	0	2026-10-22 01:15:39.872+07	2026-10-22 01:15:39.88198+07
3255	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	239	75	0	2026-10-22 01:15:39.872+07	2026-10-22 01:15:39.887394+07
3260	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	237	75	0	2026-10-22 01:15:50.373+07	2026-10-22 01:15:50.379653+07
3261	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	240	75	0	2026-10-22 01:15:50.373+07	2026-10-22 01:15:50.382519+07
3266	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	234	75	0	2026-10-22 01:16:00.874+07	2026-10-22 01:16:00.882089+07
3267	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	244	75	0	2026-10-22 01:16:00.874+07	2026-10-22 01:16:00.885029+07
3268	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	230	75	0	2026-10-22 01:16:04.368+07	2026-10-22 01:16:04.372958+07
3269	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	240	75	0	2026-10-22 01:16:04.368+07	2026-10-22 01:16:04.375123+07
3270	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	232	75	0	2026-10-22 01:16:07.879+07	2026-10-22 01:16:07.883073+07
3271	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	238	75	0	2026-10-22 01:16:07.879+07	2026-10-22 01:16:07.884626+07
3274	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	244	75	0	2026-10-22 01:16:14.874+07	2026-10-22 01:16:14.882316+07
3275	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	240	75	0	2026-10-22 01:16:14.874+07	2026-10-22 01:16:14.885214+07
3276	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	244	75	0	2026-10-22 01:16:18.367+07	2026-10-22 01:16:18.371188+07
3277	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	232	75	0	2026-10-22 01:16:18.367+07	2026-10-22 01:16:18.372698+07
3280	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	192	75	0	2026-10-22 01:16:25.372+07	2026-10-22 01:16:25.381007+07
3281	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	243	75	0	2026-10-22 01:16:25.372+07	2026-10-22 01:16:25.383761+07
3282	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	240	75	0	2026-10-22 01:16:28.869+07	2026-10-22 01:16:28.877191+07
3283	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	244	75	0	2026-10-22 01:16:28.869+07	2026-10-22 01:16:28.881255+07
3284	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	236	75	0	2026-10-22 01:16:32.377+07	2026-10-22 01:16:32.381526+07
2102	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	234	75	0	2026-10-21 22:44:06.876+07	2026-10-21 22:44:07.015914+07
2103	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	240	75	0	2026-10-21 22:44:06.876+07	2026-10-21 22:44:07.372006+07
2104	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	234	75	0	2026-10-21 22:44:10.871+07	2026-10-21 22:44:11.074083+07
2105	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	239	75	0	2026-10-21 22:44:10.871+07	2026-10-21 22:44:11.214115+07
2106	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	250	75	0	2026-10-21 22:44:14.873+07	2026-10-21 22:44:14.921293+07
2107	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	255	75	0	2026-10-21 22:44:14.873+07	2026-10-21 22:44:15.191677+07
2108	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	237	75	0	2026-10-21 22:44:18.882+07	2026-10-21 22:44:19.1723+07
2109	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	234	75	0	2026-10-21 22:44:18.882+07	2026-10-21 22:44:19.756411+07
2110	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	236	75	0	2026-10-21 22:44:23.379+07	2026-10-21 22:44:23.557842+07
2111	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	224	75	0	2026-10-21 22:44:23.379+07	2026-10-21 22:44:23.852138+07
2112	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	104	0	95.33	2026-10-21 22:44:25.207+07	2026-10-21 22:44:27.800719+07
2113	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	242	75	0	2026-10-21 22:44:27.383+07	2026-10-21 22:44:28.226713+07
2114	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	73	0	28.33	2026-10-21 22:44:29.451+07	2026-10-21 22:44:29.623526+07
2115	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	67	0	17.67	2026-10-21 22:44:29.449+07	2026-10-21 22:44:29.943399+07
2116	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	235	75	0	2026-10-21 22:44:33.382+07	2026-10-21 22:44:33.459883+07
2117	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	247	75	0	2026-10-21 22:44:33.382+07	2026-10-21 22:44:33.594608+07
2118	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	235	75	0	2026-10-21 22:44:36.881+07	2026-10-21 22:44:37.0297+07
2119	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	240	75	0	2026-10-21 22:44:36.881+07	2026-10-21 22:44:37.034718+07
2120	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	245	75	0	2026-10-21 22:44:40.383+07	2026-10-21 22:44:40.434372+07
2121	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	240	75	0	2026-10-21 22:44:40.383+07	2026-10-21 22:44:40.722229+07
2122	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	239	75	0	2026-10-21 22:44:44.377+07	2026-10-21 22:44:44.381368+07
2123	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	235	75	0	2026-10-21 22:44:44.377+07	2026-10-21 22:44:44.382905+07
2124	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	233	75	0	2026-10-21 22:44:47.88+07	2026-10-21 22:44:47.886852+07
2125	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	237	75	0	2026-10-21 22:44:47.88+07	2026-10-21 22:44:47.889056+07
2126	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	246	75	0	2026-10-21 22:44:51.386+07	2026-10-21 22:44:51.490677+07
2127	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	251	75	0	2026-10-21 22:44:51.386+07	2026-10-21 22:44:51.497104+07
2128	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	240	75	0	2026-10-21 22:44:54.885+07	2026-10-21 22:44:55.186851+07
2129	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	237	75	0	2026-10-21 22:44:54.884+07	2026-10-21 22:44:55.478853+07
2130	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	243	75	0	2026-10-21 22:44:58.881+07	2026-10-21 22:44:58.979037+07
2131	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	238	75	0	2026-10-21 22:44:58.881+07	2026-10-21 22:44:59.004886+07
2132	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	235	75	0	2026-10-21 22:45:02.366+07	2026-10-21 22:45:02.871207+07
2133	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 22:45:02.865+07	2026-10-21 22:45:02.874993+07
2134	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	236	75	0	2026-10-21 22:45:06.38+07	2026-10-21 22:45:08.743542+07
2135	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	241	75	0	2026-10-21 22:45:06.38+07	2026-10-21 22:45:09.518007+07
2136	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	online	175	0	134.33	2026-10-21 22:45:10.993+07	2026-10-21 22:45:13.463615+07
2137	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 22:45:13.378+07	2026-10-21 22:45:14.021308+07
2138	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	231	0	280.67	2026-10-21 22:45:15.897+07	2026-10-21 22:45:16.616401+07
2139	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	208	0	211	2026-10-21 22:45:15.903+07	2026-10-21 22:45:19.833832+07
2140	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	40	0	9	2026-10-21 22:45:21.04+07	2026-10-21 22:45:23.385191+07
2141	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	234	75	0	2026-10-21 22:45:23.381+07	2026-10-21 22:45:23.386711+07
2142	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	46	0	23.67	2026-10-21 22:45:24.354+07	2026-10-21 22:45:26.879368+07
2143	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	239	75	0	2026-10-21 22:45:26.871+07	2026-10-21 22:45:26.883611+07
2144	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	234	75	0	2026-10-21 22:45:30.381+07	2026-10-21 22:45:30.38611+07
2145	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	243	75	0	2026-10-21 22:45:30.381+07	2026-10-21 22:45:30.387583+07
2146	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	82	0	66.67	2026-10-21 22:48:23.003+07	2026-10-21 22:48:25.394869+07
2147	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 22:48:40.879+07	2026-10-21 22:48:40.891799+07
2148	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	unknown	62	25	29	2026-10-21 22:51:43.036+07	2026-10-21 22:51:43.040769+07
2149	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 22:51:48.371+07	2026-10-21 22:51:48.377496+07
2150	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	online	122	0	46.67	2026-10-21 22:54:50.259+07	2026-10-21 22:54:50.266434+07
2151	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	233	75	0	2026-10-21 22:54:55.37+07	2026-10-21 22:54:55.378299+07
2152	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	245	75	0	2026-10-21 22:58:02.372+07	2026-10-21 22:58:02.390104+07
2153	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	245	75	0	2026-10-21 23:01:08.88+07	2026-10-21 23:01:08.894731+07
2154	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	222	75	0	2026-10-21 23:04:15.879+07	2026-10-21 23:04:15.893432+07
2155	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 23:07:20.377+07	2026-10-21 23:07:20.393487+07
2156	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-21 23:07:25.88+07	2026-10-21 23:07:25.885047+07
2157	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	119	0	42.67	2026-10-21 23:10:15.128+07	2026-10-21 23:10:17.37772+07
2158	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 23:10:32.874+07	2026-10-21 23:10:32.879123+07
2159	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-21 23:13:37.367+07	2026-10-21 23:13:37.374345+07
2160	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-21 23:13:42.871+07	2026-10-21 23:13:42.880888+07
2161	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 23:16:50.386+07	2026-10-21 23:16:50.399774+07
2162	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	148	0	4.67	2026-10-21 23:19:39.76+07	2026-10-21 23:19:41.883581+07
2163	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 23:19:57.378+07	2026-10-21 23:19:57.383458+07
2164	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	230	75	0	2026-10-21 23:23:04.379+07	2026-10-21 23:23:04.394059+07
2165	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	223	75	0	2026-10-21 23:25:00.871+07	2026-10-21 23:25:00.877975+07
2166	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	237	75	0	2026-10-21 23:25:00.871+07	2026-10-21 23:25:00.879786+07
2167	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	256	75	0	2026-10-21 23:25:04.383+07	2026-10-21 23:25:04.399944+07
2168	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	245	75	0	2026-10-21 23:25:04.384+07	2026-10-21 23:25:04.406615+07
2169	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	239	75	0	2026-10-21 23:25:07.871+07	2026-10-21 23:25:07.875256+07
2170	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	242	75	0	2026-10-21 23:25:07.871+07	2026-10-21 23:25:07.876822+07
2171	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	235	75	0	2026-10-21 23:25:11.38+07	2026-10-21 23:25:11.391927+07
2172	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	242	75	0	2026-10-21 23:25:11.38+07	2026-10-21 23:25:11.39631+07
2173	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	238	75	0	2026-10-21 23:25:14.875+07	2026-10-21 23:25:14.880024+07
2174	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	234	75	0	2026-10-21 23:25:14.875+07	2026-10-21 23:25:14.881942+07
2175	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	235	75	0	2026-10-21 23:25:18.368+07	2026-10-21 23:25:18.374296+07
2176	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	241	75	0	2026-10-21 23:25:18.368+07	2026-10-21 23:25:18.376737+07
2177	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	234	75	0	2026-10-21 23:25:21.873+07	2026-10-21 23:25:21.878005+07
2178	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	238	75	0	2026-10-21 23:25:21.873+07	2026-10-21 23:25:21.880127+07
2179	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	60	0	25.33	2026-10-21 23:25:22.902+07	2026-10-21 23:25:25.389199+07
2180	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	236	75	0	2026-10-21 23:25:25.379+07	2026-10-21 23:25:25.393117+07
2181	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	229	75	0	2026-10-21 23:25:28.872+07	2026-10-21 23:25:28.877708+07
2182	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	237	75	0	2026-10-21 23:25:28.872+07	2026-10-21 23:25:28.879546+07
2183	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	64	0	21.67	2026-10-21 23:25:29.919+07	2026-10-21 23:25:32.38952+07
2184	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	241	75	0	2026-10-21 23:25:32.38+07	2026-10-21 23:25:32.39364+07
2185	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	233	75	0	2026-10-21 23:25:35.879+07	2026-10-21 23:25:35.884427+07
2186	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	243	75	0	2026-10-21 23:25:35.879+07	2026-10-21 23:25:35.886632+07
2187	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	250	75	0	2026-10-21 23:25:39.378+07	2026-10-21 23:25:39.3862+07
2188	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	256	75	0	2026-10-21 23:25:39.378+07	2026-10-21 23:25:39.389626+07
2189	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	247	75	0	2026-10-21 23:25:42.88+07	2026-10-21 23:25:42.885659+07
2190	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	236	75	0	2026-10-21 23:25:42.88+07	2026-10-21 23:25:42.887284+07
2191	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	226	75	0	2026-10-21 23:25:46.372+07	2026-10-21 23:25:46.383048+07
2192	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	238	75	0	2026-10-21 23:25:46.372+07	2026-10-21 23:25:46.387656+07
2193	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	236	75	0	2026-10-21 23:25:49.875+07	2026-10-21 23:25:49.878274+07
2194	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	241	75	0	2026-10-21 23:25:49.875+07	2026-10-21 23:25:49.879621+07
2195	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	242	75	0	2026-10-21 23:25:53.376+07	2026-10-21 23:25:53.379651+07
2196	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	236	75	0	2026-10-21 23:25:53.376+07	2026-10-21 23:25:53.38119+07
2197	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	223	75	0	2026-10-21 23:25:56.873+07	2026-10-21 23:25:56.876589+07
2198	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	234	75	0	2026-10-21 23:25:56.873+07	2026-10-21 23:25:56.878529+07
2199	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	233	75	0	2026-10-21 23:26:00.379+07	2026-10-21 23:26:00.383143+07
2200	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	244	75	0	2026-10-21 23:26:00.379+07	2026-10-21 23:26:00.384755+07
2201	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	237	75	0	2026-10-21 23:26:03.871+07	2026-10-21 23:26:03.876689+07
2202	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	226	75	0	2026-10-21 23:26:03.871+07	2026-10-21 23:26:03.878565+07
2203	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	231	75	0	2026-10-21 23:26:07.381+07	2026-10-21 23:26:07.386275+07
2204	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	243	75	0	2026-10-21 23:26:07.381+07	2026-10-21 23:26:07.388294+07
2205	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	238	75	0	2026-10-21 23:26:10.879+07	2026-10-21 23:26:10.883469+07
2206	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	227	75	0	2026-10-21 23:26:10.879+07	2026-10-21 23:26:10.885009+07
2207	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	231	75	0	2026-10-21 23:26:14.381+07	2026-10-21 23:26:14.391069+07
2208	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	242	75	0	2026-10-21 23:26:14.381+07	2026-10-21 23:26:14.394775+07
2209	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	232	75	0	2026-10-21 23:26:17.877+07	2026-10-21 23:26:17.880175+07
2210	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	236	75	0	2026-10-21 23:26:17.877+07	2026-10-21 23:26:17.881975+07
2211	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	222	75	0	2026-10-21 23:26:21.375+07	2026-10-21 23:26:21.387839+07
2212	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	227	75	0	2026-10-21 23:26:21.375+07	2026-10-21 23:26:21.391095+07
2213	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	230	75	0	2026-10-21 23:26:24.878+07	2026-10-21 23:26:24.883391+07
2214	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	243	75	0	2026-10-21 23:26:24.878+07	2026-10-21 23:26:24.886365+07
2215	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	241	75	0	2026-10-21 23:26:28.37+07	2026-10-21 23:26:28.376236+07
2216	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	245	75	0	2026-10-21 23:26:28.369+07	2026-10-21 23:26:28.379363+07
2217	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	240	75	0	2026-10-21 23:26:31.878+07	2026-10-21 23:26:31.884915+07
2218	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	245	75	0	2026-10-21 23:26:31.878+07	2026-10-21 23:26:31.887958+07
2221	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	230	75	0	2026-10-21 23:26:38.874+07	2026-10-21 23:26:38.877874+07
2222	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	241	75	0	2026-10-21 23:26:38.874+07	2026-10-21 23:26:38.879656+07
2225	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	239	75	0	2026-10-21 23:26:45.876+07	2026-10-21 23:26:45.87955+07
2226	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	244	75	0	2026-10-21 23:26:45.876+07	2026-10-21 23:26:45.882042+07
2227	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	244	75	0	2026-10-21 23:26:49.377+07	2026-10-21 23:26:49.383002+07
2228	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	237	75	0	2026-10-21 23:26:49.377+07	2026-10-21 23:26:49.385188+07
2229	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	227	75	0	2026-10-21 23:26:52.867+07	2026-10-21 23:26:52.871395+07
2230	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	238	75	0	2026-10-21 23:26:52.867+07	2026-10-21 23:26:52.8732+07
2231	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	235	75	0	2026-10-21 23:26:56.37+07	2026-10-21 23:26:56.373687+07
2232	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	240	75	0	2026-10-21 23:26:56.37+07	2026-10-21 23:26:56.37517+07
2235	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	242	75	0	2026-10-21 23:27:03.383+07	2026-10-21 23:27:03.390221+07
2236	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	235	75	0	2026-10-21 23:27:03.383+07	2026-10-21 23:27:03.393084+07
2239	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	236	75	0	2026-10-21 23:27:10.387+07	2026-10-21 23:27:10.397006+07
2240	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	240	75	0	2026-10-21 23:27:10.387+07	2026-10-21 23:27:10.401915+07
2245	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	37	0	17	2026-10-21 23:27:18.302+07	2026-10-21 23:27:20.876041+07
2246	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	238	75	0	2026-10-21 23:27:20.872+07	2026-10-21 23:27:20.877555+07
2247	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	50	0	19.67	2026-10-21 23:27:21.855+07	2026-10-21 23:27:21.867023+07
2248	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	47	0	16.67	2026-10-21 23:27:21.862+07	2026-10-21 23:27:21.868907+07
2253	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	230	75	0	2026-10-21 23:27:32.367+07	2026-10-21 23:27:32.372711+07
2254	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	237	75	0	2026-10-21 23:27:32.367+07	2026-10-21 23:27:32.374905+07
2255	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	224	75	0	2026-10-21 23:27:35.88+07	2026-10-21 23:27:35.884042+07
2256	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	236	75	0	2026-10-21 23:27:35.88+07	2026-10-21 23:27:35.885511+07
2261	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	222	75	0	2026-10-21 23:27:46.374+07	2026-10-21 23:27:46.37888+07
2262	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	216	75	0	2026-10-21 23:27:46.374+07	2026-10-21 23:27:46.381561+07
2269	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	online	145	0	9.33	2026-10-21 23:27:58.749+07	2026-10-21 23:27:58.753092+07
2270	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	120	0	39.33	2026-10-21 23:27:58.642+07	2026-10-21 23:27:58.754733+07
2275	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	34	0	4.33	2026-10-21 23:28:03.8+07	2026-10-21 23:28:06.372076+07
2276	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	236	75	0	2026-10-21 23:28:06.368+07	2026-10-21 23:28:06.373485+07
2865	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	223	75	0	2026-10-22 00:19:07.376+07	2026-10-22 00:19:07.382611+07
3003	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	51	0	19.67	2026-10-22 00:35:20.862+07	2026-10-22 00:35:23.885195+07
3004	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	739	75	0	2026-10-22 00:35:23.871+07	2026-10-22 00:35:23.890599+07
3007	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	242	75	0	2026-10-22 00:35:31.376+07	2026-10-22 00:35:31.380231+07
3008	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	233	75	0	2026-10-22 00:35:31.376+07	2026-10-22 00:35:31.38209+07
3009	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	235	75	0	2026-10-22 00:35:34.88+07	2026-10-22 00:35:34.884882+07
3010	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	244	75	0	2026-10-22 00:35:34.88+07	2026-10-22 00:35:34.887335+07
3013	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	231	75	0	2026-10-22 00:35:41.878+07	2026-10-22 00:35:41.887364+07
3014	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	245	75	0	2026-10-22 00:35:41.878+07	2026-10-22 00:35:41.892412+07
3015	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	238	75	0	2026-10-22 00:35:45.375+07	2026-10-22 00:35:45.379845+07
3016	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	250	75	0	2026-10-22 00:35:45.375+07	2026-10-22 00:35:45.381765+07
3017	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	240	75	0	2026-10-22 00:35:48.876+07	2026-10-22 00:35:48.886461+07
3018	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	230	75	0	2026-10-22 00:35:48.876+07	2026-10-22 00:35:48.892124+07
3019	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	230	75	0	2026-10-22 00:35:52.378+07	2026-10-22 00:35:52.382222+07
3020	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	239	75	0	2026-10-22 00:35:52.378+07	2026-10-22 00:35:52.384155+07
3021	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	225	75	0	2026-10-22 00:35:55.874+07	2026-10-22 00:35:55.879505+07
3022	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	214	75	0	2026-10-22 00:35:55.874+07	2026-10-22 00:35:55.882025+07
3025	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	241	75	0	2026-10-22 00:36:02.881+07	2026-10-22 00:36:02.886994+07
3026	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	231	75	0	2026-10-22 00:36:02.88+07	2026-10-22 00:36:02.889041+07
3029	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	245	75	0	2026-10-22 00:36:09.867+07	2026-10-22 00:36:09.871652+07
3030	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	235	75	0	2026-10-22 00:36:09.867+07	2026-10-22 00:36:09.873155+07
3031	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	240	75	0	2026-10-22 00:36:13.387+07	2026-10-22 00:36:13.396912+07
3032	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	236	75	0	2026-10-22 00:36:13.387+07	2026-10-22 00:36:13.400953+07
3152	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	212	75	0	2026-10-22 00:49:41.869+07	2026-10-22 00:49:41.875353+07
3153	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	223	75	0	2026-10-22 00:49:41.868+07	2026-10-22 00:49:41.877234+07
3156	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	223	75	0	2026-10-22 00:49:48.886+07	2026-10-22 00:49:48.891815+07
3157	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	238	75	0	2026-10-22 00:49:48.886+07	2026-10-22 00:49:48.894517+07
3158	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	235	75	0	2026-10-22 00:49:52.371+07	2026-10-22 00:49:52.378022+07
3159	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	242	75	0	2026-10-22 00:49:52.37+07	2026-10-22 00:49:52.382608+07
2219	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	263	75	0	2026-10-21 23:26:35.376+07	2026-10-21 23:26:35.380487+07
2220	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	253	75	0	2026-10-21 23:26:35.376+07	2026-10-21 23:26:35.383494+07
2223	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	241	75	0	2026-10-21 23:26:42.386+07	2026-10-21 23:26:42.395783+07
2224	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	229	75	0	2026-10-21 23:26:42.386+07	2026-10-21 23:26:42.401414+07
2233	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	239	75	0	2026-10-21 23:26:59.868+07	2026-10-21 23:26:59.872542+07
2234	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	229	75	0	2026-10-21 23:26:59.868+07	2026-10-21 23:26:59.874335+07
2237	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	229	75	0	2026-10-21 23:27:06.877+07	2026-10-21 23:27:06.884229+07
2238	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	234	75	0	2026-10-21 23:27:06.877+07	2026-10-21 23:27:06.894501+07
2241	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	236	75	0	2026-10-21 23:27:13.872+07	2026-10-21 23:27:13.878967+07
2242	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	243	75	0	2026-10-21 23:27:13.872+07	2026-10-21 23:27:13.880755+07
2243	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	237	75	0	2026-10-21 23:27:17.379+07	2026-10-21 23:27:17.383404+07
2244	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	248	75	0	2026-10-21 23:27:17.379+07	2026-10-21 23:27:17.384871+07
2249	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	230	75	0	2026-10-21 23:27:25.38+07	2026-10-21 23:27:25.384337+07
2250	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	242	75	0	2026-10-21 23:27:25.38+07	2026-10-21 23:27:25.386319+07
2251	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	231	75	0	2026-10-21 23:27:28.875+07	2026-10-21 23:27:28.879177+07
2252	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	236	75	0	2026-10-21 23:27:28.875+07	2026-10-21 23:27:28.881203+07
2257	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	241	75	0	2026-10-21 23:27:39.374+07	2026-10-21 23:27:39.378086+07
2258	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	246	75	0	2026-10-21 23:27:39.374+07	2026-10-21 23:27:39.379647+07
2259	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	224	75	0	2026-10-21 23:27:42.879+07	2026-10-21 23:27:42.88777+07
2260	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	236	75	0	2026-10-21 23:27:42.879+07	2026-10-21 23:27:42.890651+07
2263	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	230	75	0	2026-10-21 23:27:49.868+07	2026-10-21 23:27:49.872178+07
2264	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	241	75	0	2026-10-21 23:27:49.868+07	2026-10-21 23:27:49.873569+07
2265	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	235	75	0	2026-10-21 23:27:53.38+07	2026-10-21 23:27:53.883642+07
2266	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 23:27:53.879+07	2026-10-21 23:27:53.885936+07
2267	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	237	75	0	2026-10-21 23:27:57.378+07	2026-10-21 23:27:57.385209+07
2268	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	233	75	0	2026-10-21 23:27:57.378+07	2026-10-21 23:27:57.387369+07
2271	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	37	0	4.33	2026-10-21 23:27:59.688+07	2026-10-21 23:27:59.69621+07
2272	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	36	0	4.33	2026-10-21 23:27:59.692+07	2026-10-21 23:27:59.697579+07
2273	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	44	0	8.33	2026-10-21 23:28:00.637+07	2026-10-21 23:28:02.874604+07
2274	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	239	75	0	2026-10-21 23:28:02.871+07	2026-10-21 23:28:02.875926+07
2277	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	230	75	0	2026-10-21 23:28:09.868+07	2026-10-21 23:28:09.872314+07
2278	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	241	75	0	2026-10-21 23:28:09.868+07	2026-10-21 23:28:09.873662+07
2279	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	218	75	0	2026-10-21 23:31:20.384+07	2026-10-21 23:31:20.3889+07
2280	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-21 23:34:27.374+07	2026-10-21 23:34:27.380164+07
2281	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-21 23:35:41.374+07	2026-10-21 23:35:41.381446+07
2282	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	233	75	0	2026-10-21 23:35:41.374+07	2026-10-21 23:35:41.383536+07
2283	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	239	75	0	2026-10-21 23:35:44.876+07	2026-10-21 23:35:44.882827+07
2284	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	228	75	0	2026-10-21 23:35:44.876+07	2026-10-21 23:35:44.884993+07
2285	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	230	75	0	2026-10-21 23:35:48.372+07	2026-10-21 23:35:48.378389+07
2286	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	239	75	0	2026-10-21 23:35:48.372+07	2026-10-21 23:35:48.38048+07
2287	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	249	75	0	2026-10-21 23:35:51.878+07	2026-10-21 23:35:51.889836+07
2288	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	238	75	0	2026-10-21 23:35:51.877+07	2026-10-21 23:35:51.895101+07
2289	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	240	75	0	2026-10-21 23:35:55.38+07	2026-10-21 23:35:55.385538+07
2290	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	230	75	0	2026-10-21 23:35:55.381+07	2026-10-21 23:35:55.387742+07
2291	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	229	75	0	2026-10-21 23:35:58.883+07	2026-10-21 23:35:58.893561+07
2292	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	240	75	0	2026-10-21 23:35:58.883+07	2026-10-21 23:35:58.897618+07
2293	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	226	75	0	2026-10-21 23:36:02.372+07	2026-10-21 23:36:02.380496+07
2294	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	236	75	0	2026-10-21 23:36:02.372+07	2026-10-21 23:36:02.38361+07
2295	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	62	0	50	2026-10-21 23:36:03.407+07	2026-10-21 23:36:05.881321+07
2296	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	243	75	0	2026-10-21 23:36:05.875+07	2026-10-21 23:36:05.883702+07
2297	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	233	75	0	2026-10-21 23:36:09.367+07	2026-10-21 23:36:09.372283+07
2298	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	240	75	0	2026-10-21 23:36:09.367+07	2026-10-21 23:36:09.373735+07
2299	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	60	0	34.33	2026-10-21 23:36:10.4+07	2026-10-21 23:36:12.876935+07
2300	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	248	75	0	2026-10-21 23:36:12.871+07	2026-10-21 23:36:12.87907+07
2301	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	238	75	0	2026-10-21 23:36:16.372+07	2026-10-21 23:36:16.377417+07
2302	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	235	75	0	2026-10-21 23:36:16.372+07	2026-10-21 23:36:16.379611+07
2303	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	246	75	0	2026-10-21 23:36:19.875+07	2026-10-21 23:36:19.885977+07
2304	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	236	75	0	2026-10-21 23:36:19.876+07	2026-10-21 23:36:19.889585+07
2305	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	228	75	0	2026-10-21 23:36:23.373+07	2026-10-21 23:36:23.377298+07
2306	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	221	75	0	2026-10-21 23:36:23.373+07	2026-10-21 23:36:23.379268+07
2309	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	229	75	0	2026-10-21 23:36:30.37+07	2026-10-21 23:36:30.375058+07
2310	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	238	75	0	2026-10-21 23:36:30.37+07	2026-10-21 23:36:30.376845+07
2866	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-22 00:22:14.367+07	2026-10-22 00:22:14.375826+07
3027	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	245	75	0	2026-10-22 00:36:06.374+07	2026-10-22 00:36:06.385344+07
3028	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	232	75	0	2026-10-22 00:36:06.374+07	2026-10-22 00:36:06.388112+07
3033	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	230	75	0	2026-10-22 00:36:16.882+07	2026-10-22 00:36:16.888817+07
3034	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	240	75	0	2026-10-22 00:36:16.882+07	2026-10-22 00:36:16.891565+07
3035	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	247	75	0	2026-10-22 00:36:20.379+07	2026-10-22 00:36:20.385085+07
3036	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	242	75	0	2026-10-22 00:36:20.379+07	2026-10-22 00:36:20.387791+07
3039	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	242	75	0	2026-10-22 00:36:27.375+07	2026-10-22 00:36:27.385796+07
3040	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	238	75	0	2026-10-22 00:36:27.375+07	2026-10-22 00:36:27.390344+07
3041	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	216	75	0	2026-10-22 00:36:30.871+07	2026-10-22 00:36:30.878346+07
3042	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	227	75	0	2026-10-22 00:36:30.871+07	2026-10-22 00:36:30.882387+07
3045	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	231	75	0	2026-10-22 00:36:37.877+07	2026-10-22 00:36:37.887253+07
3046	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	241	75	0	2026-10-22 00:36:37.877+07	2026-10-22 00:36:37.892728+07
3051	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	232	75	0	2026-10-22 00:36:48.375+07	2026-10-22 00:36:48.383828+07
3052	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	242	75	0	2026-10-22 00:36:48.375+07	2026-10-22 00:36:48.387445+07
3055	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	236	75	0	2026-10-22 00:36:55.373+07	2026-10-22 00:36:55.377759+07
3056	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	246	75	0	2026-10-22 00:36:55.373+07	2026-10-22 00:36:55.379983+07
3057	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	228	75	0	2026-10-22 00:36:58.875+07	2026-10-22 00:36:58.881692+07
3058	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	216	75	0	2026-10-22 00:36:58.875+07	2026-10-22 00:36:58.884842+07
3059	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	235	75	0	2026-10-22 00:37:02.368+07	2026-10-22 00:37:02.372937+07
3060	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	238	75	0	2026-10-22 00:37:02.368+07	2026-10-22 00:37:02.374618+07
3063	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	247	75	0	2026-10-22 00:37:09.383+07	2026-10-22 00:37:09.38867+07
3064	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	244	75	0	2026-10-22 00:37:09.382+07	2026-10-22 00:37:09.391156+07
3065	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	58	0	24.33	2026-10-22 00:37:10.401+07	2026-10-22 00:37:12.879215+07
3066	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	239	75	0	2026-10-22 00:37:12.875+07	2026-10-22 00:37:12.880722+07
3067	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	41	0	7.67	2026-10-22 00:37:13.814+07	2026-10-22 00:37:13.818858+07
3068	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	41	0	12.67	2026-10-22 00:37:13.81+07	2026-10-22 00:37:13.820522+07
3073	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	245	75	0	2026-10-22 00:37:24.377+07	2026-10-22 00:37:24.381448+07
3074	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	249	75	0	2026-10-22 00:37:24.377+07	2026-10-22 00:37:24.383382+07
3075	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	219	75	0	2026-10-22 00:37:27.867+07	2026-10-22 00:37:27.871334+07
3076	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	229	75	0	2026-10-22 00:37:27.867+07	2026-10-22 00:37:27.872934+07
3081	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	228	75	0	2026-10-22 00:37:38.369+07	2026-10-22 00:37:38.373574+07
3082	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	241	75	0	2026-10-22 00:37:38.369+07	2026-10-22 00:37:38.375041+07
3087	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	234	75	0	2026-10-22 00:37:49.376+07	2026-10-22 00:37:49.384387+07
3088	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	240	75	0	2026-10-22 00:37:49.373+07	2026-10-22 00:37:49.3874+07
3091	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	53	0	7.33	2026-10-22 00:37:54.418+07	2026-10-22 00:37:54.429523+07
3092	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	54	0	13	2026-10-22 00:37:54.424+07	2026-10-22 00:37:54.433985+07
3160	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	231	75	0	2026-10-22 00:49:55.879+07	2026-10-22 00:49:55.883535+07
3161	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	237	75	0	2026-10-22 00:49:55.879+07	2026-10-22 00:49:55.885344+07
3162	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	237	75	0	2026-10-22 00:49:59.366+07	2026-10-22 00:49:59.37312+07
3163	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	236	75	0	2026-10-22 00:49:59.367+07	2026-10-22 00:49:59.375478+07
3166	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	239	75	0	2026-10-22 00:50:06.372+07	2026-10-22 00:50:06.377921+07
3167	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	235	75	0	2026-10-22 00:50:06.372+07	2026-10-22 00:50:06.379769+07
3170	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	228	75	0	2026-10-22 00:50:13.382+07	2026-10-22 00:50:13.387444+07
3171	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	238	75	0	2026-10-22 00:50:13.382+07	2026-10-22 00:50:13.389298+07
3178	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	226	75	0	2026-10-22 00:50:27.367+07	2026-10-22 00:50:27.371779+07
3179	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	236	75	0	2026-10-22 00:50:27.367+07	2026-10-22 00:50:27.373472+07
3180	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	237	75	0	2026-10-22 00:50:30.88+07	2026-10-22 00:50:30.885505+07
3181	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	226	75	0	2026-10-22 00:50:30.88+07	2026-10-22 00:50:30.887697+07
3184	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	37	0	10	2026-10-22 00:50:35.288+07	2026-10-22 00:50:37.89024+07
3185	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	242	75	0	2026-10-22 00:50:37.882+07	2026-10-22 00:50:37.893707+07
3188	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	234	75	0	2026-10-22 00:50:42.379+07	2026-10-22 00:50:42.38526+07
3189	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	239	75	0	2026-10-22 00:50:42.378+07	2026-10-22 00:50:42.388182+07
3192	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	221	75	0	2026-10-22 00:50:49.372+07	2026-10-22 00:50:49.376901+07
2307	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	233	75	0	2026-10-21 23:36:26.879+07	2026-10-21 23:36:26.890519+07
2308	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	221	75	0	2026-10-21 23:36:26.879+07	2026-10-21 23:36:26.895885+07
2311	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	228	75	0	2026-10-21 23:36:33.876+07	2026-10-21 23:36:33.882729+07
2312	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	245	75	0	2026-10-21 23:36:33.875+07	2026-10-21 23:36:33.886971+07
2313	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	233	75	0	2026-10-21 23:36:37.372+07	2026-10-21 23:36:37.379524+07
2314	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	237	75	0	2026-10-21 23:36:37.373+07	2026-10-21 23:36:37.381661+07
2315	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	234	75	0	2026-10-21 23:36:40.876+07	2026-10-21 23:36:40.881394+07
2316	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	243	75	0	2026-10-21 23:36:40.877+07	2026-10-21 23:36:40.883388+07
2317	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	228	75	0	2026-10-21 23:36:44.372+07	2026-10-21 23:36:44.376362+07
2318	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	238	75	0	2026-10-21 23:36:44.372+07	2026-10-21 23:36:44.378148+07
2319	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	243	75	0	2026-10-21 23:36:47.873+07	2026-10-21 23:36:47.877923+07
2320	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	231	75	0	2026-10-21 23:36:47.873+07	2026-10-21 23:36:47.879824+07
2321	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	236	75	0	2026-10-21 23:36:51.376+07	2026-10-21 23:36:51.380502+07
2322	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	240	75	0	2026-10-21 23:36:51.376+07	2026-10-21 23:36:51.381846+07
2323	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	234	75	0	2026-10-21 23:36:54.868+07	2026-10-21 23:36:54.880994+07
2324	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	224	75	0	2026-10-21 23:36:54.867+07	2026-10-21 23:36:54.898442+07
2325	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	237	75	0	2026-10-21 23:36:58.38+07	2026-10-21 23:36:58.389171+07
2326	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	229	75	0	2026-10-21 23:36:58.38+07	2026-10-21 23:36:58.391817+07
2327	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	234	75	0	2026-10-21 23:37:01.874+07	2026-10-21 23:37:01.881275+07
2328	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	244	75	0	2026-10-21 23:37:01.874+07	2026-10-21 23:37:01.885652+07
2329	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	226	75	0	2026-10-21 23:37:05.372+07	2026-10-21 23:37:05.37803+07
2330	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	221	75	0	2026-10-21 23:37:05.372+07	2026-10-21 23:37:05.379661+07
2331	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	248	75	0	2026-10-21 23:37:08.883+07	2026-10-21 23:37:08.892593+07
2332	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	237	75	0	2026-10-21 23:37:08.883+07	2026-10-21 23:37:08.896016+07
2333	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	213	75	0	2026-10-21 23:37:12.377+07	2026-10-21 23:37:12.383977+07
2334	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	223	75	0	2026-10-21 23:37:12.377+07	2026-10-21 23:37:12.399228+07
2335	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	237	75	0	2026-10-21 23:37:15.874+07	2026-10-21 23:37:15.884572+07
2336	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	230	75	0	2026-10-21 23:37:15.874+07	2026-10-21 23:37:15.889419+07
2337	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	241	75	0	2026-10-21 23:37:19.374+07	2026-10-21 23:37:19.377774+07
2338	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	229	75	0	2026-10-21 23:37:19.374+07	2026-10-21 23:37:19.379136+07
2339	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	235	75	0	2026-10-21 23:37:22.872+07	2026-10-21 23:37:22.876836+07
2340	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	247	75	0	2026-10-21 23:37:22.872+07	2026-10-21 23:37:22.878588+07
2341	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	233	75	0	2026-10-21 23:37:26.369+07	2026-10-21 23:37:26.374851+07
2342	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	238	75	0	2026-10-21 23:37:26.369+07	2026-10-21 23:37:26.377252+07
2343	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	243	75	0	2026-10-21 23:37:29.879+07	2026-10-21 23:37:29.886433+07
2344	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	235	75	0	2026-10-21 23:37:29.879+07	2026-10-21 23:37:29.890487+07
2345	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	231	75	0	2026-10-21 23:37:33.375+07	2026-10-21 23:37:33.379753+07
2346	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	242	75	0	2026-10-21 23:37:33.375+07	2026-10-21 23:37:33.381102+07
2347	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	253	75	0	2026-10-21 23:37:36.874+07	2026-10-21 23:37:36.879582+07
2348	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	247	75	0	2026-10-21 23:37:36.875+07	2026-10-21 23:37:36.881487+07
2349	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	239	75	0	2026-10-21 23:37:40.374+07	2026-10-21 23:37:40.378794+07
2350	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	233	75	0	2026-10-21 23:37:40.374+07	2026-10-21 23:37:40.380685+07
2351	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	245	75	0	2026-10-21 23:37:43.869+07	2026-10-21 23:37:43.875508+07
2352	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	236	75	0	2026-10-21 23:37:43.869+07	2026-10-21 23:37:43.878006+07
2353	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	237	75	0	2026-10-21 23:37:47.37+07	2026-10-21 23:37:47.374896+07
2354	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	244	75	0	2026-10-21 23:37:47.37+07	2026-10-21 23:37:47.37637+07
2355	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	264	75	0	2026-10-21 23:37:50.877+07	2026-10-21 23:37:50.883451+07
2356	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	266	75	0	2026-10-21 23:37:50.877+07	2026-10-21 23:37:50.887058+07
2357	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	237	75	0	2026-10-21 23:37:54.377+07	2026-10-21 23:37:54.383857+07
2358	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	225	75	0	2026-10-21 23:37:54.377+07	2026-10-21 23:37:54.38735+07
2359	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	231	75	0	2026-10-21 23:37:57.883+07	2026-10-21 23:37:57.889673+07
2360	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	241	75	0	2026-10-21 23:37:57.883+07	2026-10-21 23:37:57.891924+07
2361	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	67	0	14.33	2026-10-21 23:37:58.936+07	2026-10-21 23:38:01.384538+07
2362	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	237	75	0	2026-10-21 23:38:01.38+07	2026-10-21 23:38:01.38617+07
2363	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	36	0	1	2026-10-21 23:38:02.319+07	2026-10-21 23:38:02.326247+07
2364	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	36	0	1.67	2026-10-21 23:38:02.323+07	2026-10-21 23:38:02.327645+07
2365	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	242	75	0	2026-10-21 23:38:05.871+07	2026-10-21 23:38:05.874597+07
2366	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	246	75	0	2026-10-21 23:38:05.871+07	2026-10-21 23:38:05.876209+07
2367	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	237	75	0	2026-10-21 23:38:09.378+07	2026-10-21 23:38:09.385848+07
2368	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	232	75	0	2026-10-21 23:38:09.378+07	2026-10-21 23:38:09.388765+07
2371	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	237	75	0	2026-10-21 23:38:16.377+07	2026-10-21 23:38:16.381355+07
2372	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	232	75	0	2026-10-21 23:38:16.377+07	2026-10-21 23:38:16.383668+07
2373	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	223	75	0	2026-10-21 23:38:19.882+07	2026-10-21 23:38:19.888008+07
2374	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	236	75	0	2026-10-21 23:38:19.882+07	2026-10-21 23:38:19.890584+07
2377	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	243	75	0	2026-10-21 23:38:26.868+07	2026-10-21 23:38:26.872715+07
2378	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	235	75	0	2026-10-21 23:38:26.869+07	2026-10-21 23:38:26.874487+07
2381	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	258	75	0	2026-10-21 23:38:33.871+07	2026-10-21 23:38:34.378328+07
2382	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 23:38:34.373+07	2026-10-21 23:38:34.381657+07
2387	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	46	0	15.67	2026-10-21 23:38:40.322+07	2026-10-21 23:38:40.32864+07
2388	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	43	0	13.67	2026-10-21 23:38:40.325+07	2026-10-21 23:38:40.330076+07
2389	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	57	0	41.67	2026-10-21 23:38:41.338+07	2026-10-21 23:38:43.873436+07
2390	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	240	75	0	2026-10-21 23:38:43.868+07	2026-10-21 23:38:43.875743+07
2867	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-22 00:25:21.873+07	2026-10-22 00:25:21.886331+07
3037	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	243	75	0	2026-10-22 00:36:23.875+07	2026-10-22 00:36:23.888471+07
3038	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	234	75	0	2026-10-22 00:36:23.876+07	2026-10-22 00:36:23.891845+07
3043	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	244	75	0	2026-10-22 00:36:34.374+07	2026-10-22 00:36:34.381528+07
3044	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	234	75	0	2026-10-22 00:36:34.375+07	2026-10-22 00:36:34.384883+07
3047	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	234	75	0	2026-10-22 00:36:41.378+07	2026-10-22 00:36:41.382831+07
3048	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	246	75	0	2026-10-22 00:36:41.378+07	2026-10-22 00:36:41.384986+07
3049	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	241	75	0	2026-10-22 00:36:44.87+07	2026-10-22 00:36:44.87786+07
3050	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	230	75	0	2026-10-22 00:36:44.869+07	2026-10-22 00:36:44.881862+07
3053	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	255	75	0	2026-10-22 00:36:51.872+07	2026-10-22 00:36:51.879567+07
3054	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	248	75	0	2026-10-22 00:36:51.872+07	2026-10-22 00:36:51.883588+07
3061	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	242	75	0	2026-10-22 00:37:05.873+07	2026-10-22 00:37:05.88015+07
3062	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	231	75	0	2026-10-22 00:37:05.873+07	2026-10-22 00:37:05.884438+07
3069	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	234	75	0	2026-10-22 00:37:17.375+07	2026-10-22 00:37:17.380123+07
3070	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	244	75	0	2026-10-22 00:37:17.375+07	2026-10-22 00:37:17.382267+07
3071	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	242	75	0	2026-10-22 00:37:20.87+07	2026-10-22 00:37:20.87842+07
3072	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	231	75	0	2026-10-22 00:37:20.87+07	2026-10-22 00:37:20.882631+07
3077	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	230	75	0	2026-10-22 00:37:31.371+07	2026-10-22 00:37:31.375613+07
3078	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	238	75	0	2026-10-22 00:37:31.371+07	2026-10-22 00:37:31.377395+07
3079	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	242	75	0	2026-10-22 00:37:34.881+07	2026-10-22 00:37:34.886638+07
3080	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	231	75	0	2026-10-22 00:37:34.881+07	2026-10-22 00:37:34.888694+07
3083	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	241	75	0	2026-10-22 00:37:41.877+07	2026-10-22 00:37:41.887655+07
3084	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	232	75	0	2026-10-22 00:37:41.877+07	2026-10-22 00:37:41.891299+07
3085	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	233	75	0	2026-10-22 00:37:45.375+07	2026-10-22 00:37:45.889745+07
3086	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 00:37:45.88+07	2026-10-22 00:37:45.894315+07
3089	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 00:37:53.374+07	2026-10-22 00:37:53.393013+07
3090	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	51	0	13.33	2026-10-22 00:37:50.374+07	2026-10-22 00:37:53.419858+07
3093	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	66	0	27.67	2026-10-22 00:37:55.466+07	2026-10-22 00:37:57.890033+07
3094	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	242	75	0	2026-10-22 00:37:57.88+07	2026-10-22 00:37:57.895206+07
3095	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	48	0	25.67	2026-10-22 00:37:58.875+07	2026-10-22 00:38:01.3808+07
3096	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	237	75	0	2026-10-22 00:38:01.375+07	2026-10-22 00:38:01.382728+07
3097	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	228	75	0	2026-10-22 00:38:04.874+07	2026-10-22 00:38:04.87975+07
3098	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	215	75	0	2026-10-22 00:38:04.874+07	2026-10-22 00:38:04.883019+07
3168	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	234	75	0	2026-10-22 00:50:09.874+07	2026-10-22 00:50:09.881158+07
3169	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	240	75	0	2026-10-22 00:50:09.874+07	2026-10-22 00:50:09.883104+07
3172	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	220	75	0	2026-10-22 00:50:16.875+07	2026-10-22 00:50:16.879294+07
3173	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	224	75	0	2026-10-22 00:50:16.875+07	2026-10-22 00:50:16.880954+07
3174	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	247	75	0	2026-10-22 00:50:20.376+07	2026-10-22 00:50:20.381616+07
3175	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	235	75	0	2026-10-22 00:50:20.376+07	2026-10-22 00:50:20.383518+07
3176	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	237	75	0	2026-10-22 00:50:23.868+07	2026-10-22 00:50:23.872614+07
3177	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	232	75	0	2026-10-22 00:50:23.868+07	2026-10-22 00:50:23.874148+07
3182	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	255	75	0	2026-10-22 00:50:34.373+07	2026-10-22 00:50:34.378052+07
3183	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	244	75	0	2026-10-22 00:50:34.373+07	2026-10-22 00:50:34.380226+07
3186	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	42	0	7.67	2026-10-22 00:50:38.852+07	2026-10-22 00:50:38.855849+07
2369	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	247	75	0	2026-10-21 23:38:12.884+07	2026-10-21 23:38:12.894653+07
2370	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	237	75	0	2026-10-21 23:38:12.884+07	2026-10-21 23:38:12.899407+07
2375	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	225	75	0	2026-10-21 23:38:23.368+07	2026-10-21 23:38:23.371365+07
2376	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	235	75	0	2026-10-21 23:38:23.368+07	2026-10-21 23:38:23.372773+07
2379	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	240	75	0	2026-10-21 23:38:30.38+07	2026-10-21 23:38:30.386661+07
2380	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	229	75	0	2026-10-21 23:38:30.38+07	2026-10-21 23:38:30.39009+07
2383	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	241	75	0	2026-10-21 23:38:37.877+07	2026-10-21 23:38:37.88235+07
2384	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	236	75	0	2026-10-21 23:38:37.877+07	2026-10-21 23:38:37.884804+07
2385	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	online	170	0	77	2026-10-21 23:38:39.357+07	2026-10-21 23:38:39.362097+07
2386	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	69	0	53.33	2026-10-21 23:38:38.949+07	2026-10-21 23:38:39.36516+07
2391	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	54	0	19.67	2026-10-21 23:38:44.873+07	2026-10-21 23:38:47.380919+07
2392	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	238	75	0	2026-10-21 23:38:47.377+07	2026-10-21 23:38:47.382804+07
2393	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	210	75	0	2026-10-21 23:38:50.874+07	2026-10-21 23:38:50.878357+07
2394	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	222	75	0	2026-10-21 23:38:50.874+07	2026-10-21 23:38:50.879798+07
2395	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	221	75	0	2026-10-21 23:41:15.373+07	2026-10-21 23:41:15.37996+07
2396	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	232	75	0	2026-10-21 23:41:34.878+07	2026-10-21 23:41:34.89748+07
2397	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	243	75	0	2026-10-21 23:41:34.877+07	2026-10-21 23:41:34.90211+07
2398	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	742	75	0	2026-10-21 23:41:36.865+07	2026-10-21 23:41:36.86926+07
2399	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	226	75	0	2026-10-21 23:41:36.38+07	2026-10-21 23:41:36.870768+07
2400	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	256	75	0	2026-10-21 23:41:40.385+07	2026-10-21 23:41:40.391316+07
2401	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	245	75	0	2026-10-21 23:41:40.385+07	2026-10-21 23:41:40.39489+07
2402	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	234	75	0	2026-10-21 23:41:43.87+07	2026-10-21 23:41:43.877889+07
2403	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	243	75	0	2026-10-21 23:41:43.87+07	2026-10-21 23:41:43.883488+07
2404	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	238	75	0	2026-10-21 23:41:47.379+07	2026-10-21 23:41:47.383683+07
2405	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	244	75	0	2026-10-21 23:41:47.379+07	2026-10-21 23:41:47.385098+07
2406	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	237	75	0	2026-10-21 23:41:50.884+07	2026-10-21 23:41:50.895345+07
2407	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	244	75	0	2026-10-21 23:41:50.884+07	2026-10-21 23:41:50.901042+07
2408	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	235	75	0	2026-10-21 23:41:54.367+07	2026-10-21 23:41:54.370972+07
2409	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	247	75	0	2026-10-21 23:41:54.367+07	2026-10-21 23:41:54.372404+07
2410	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	232	75	0	2026-10-21 23:41:57.87+07	2026-10-21 23:41:57.880193+07
2411	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	243	75	0	2026-10-21 23:41:57.87+07	2026-10-21 23:41:57.884757+07
2412	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	56	0	25	2026-10-21 23:41:58.877+07	2026-10-21 23:42:01.384811+07
2413	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	244	75	0	2026-10-21 23:42:01.377+07	2026-10-21 23:42:01.387867+07
2414	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	233	75	0	2026-10-21 23:42:04.872+07	2026-10-21 23:42:04.876233+07
2415	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	237	75	0	2026-10-21 23:42:04.872+07	2026-10-21 23:42:04.878243+07
2416	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	47	0	13.67	2026-10-21 23:42:05.841+07	2026-10-21 23:42:08.372942+07
2417	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	237	75	0	2026-10-21 23:42:08.368+07	2026-10-21 23:42:08.375053+07
2418	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	246	75	0	2026-10-21 23:42:11.884+07	2026-10-21 23:42:11.890955+07
2419	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	250	75	0	2026-10-21 23:42:11.884+07	2026-10-21 23:42:11.89406+07
2420	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	244	75	0	2026-10-21 23:42:15.371+07	2026-10-21 23:42:15.379991+07
2421	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	240	75	0	2026-10-21 23:42:15.371+07	2026-10-21 23:42:15.393819+07
2422	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	237	75	0	2026-10-21 23:42:18.88+07	2026-10-21 23:42:18.884277+07
2423	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	241	75	0	2026-10-21 23:42:18.88+07	2026-10-21 23:42:18.885782+07
2424	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	228	75	0	2026-10-21 23:42:22.373+07	2026-10-21 23:42:22.379174+07
2425	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	219	75	0	2026-10-21 23:42:22.373+07	2026-10-21 23:42:22.381711+07
2426	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	243	75	0	2026-10-21 23:42:25.877+07	2026-10-21 23:42:25.88367+07
2427	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	239	75	0	2026-10-21 23:42:25.876+07	2026-10-21 23:42:25.885688+07
2428	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	237	75	0	2026-10-21 23:42:29.377+07	2026-10-21 23:42:29.386057+07
2429	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	241	75	0	2026-10-21 23:42:29.377+07	2026-10-21 23:42:29.389265+07
2430	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	244	75	0	2026-10-21 23:42:32.879+07	2026-10-21 23:42:32.88659+07
2431	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	233	75	0	2026-10-21 23:42:32.879+07	2026-10-21 23:42:32.888559+07
2432	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	230	75	0	2026-10-21 23:42:36.367+07	2026-10-21 23:42:36.373012+07
2433	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	242	75	0	2026-10-21 23:42:36.367+07	2026-10-21 23:42:36.375573+07
2434	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	230	75	0	2026-10-21 23:42:39.888+07	2026-10-21 23:42:39.896512+07
2435	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	240	75	0	2026-10-21 23:42:39.888+07	2026-10-21 23:42:39.899675+07
2436	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	239	75	0	2026-10-21 23:42:43.38+07	2026-10-21 23:42:43.384355+07
2437	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	214	75	0	2026-10-21 23:42:43.38+07	2026-10-21 23:42:43.386114+07
2438	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	257	75	0	2026-10-21 23:42:46.884+07	2026-10-21 23:42:46.891712+07
2439	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	247	75	0	2026-10-21 23:42:46.884+07	2026-10-21 23:42:46.896043+07
2440	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	235	75	0	2026-10-21 23:42:50.378+07	2026-10-21 23:42:50.381617+07
2441	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	246	75	0	2026-10-21 23:42:50.378+07	2026-10-21 23:42:50.383147+07
2444	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	230	75	0	2026-10-21 23:42:57.384+07	2026-10-21 23:42:57.394498+07
2445	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	241	75	0	2026-10-21 23:42:57.384+07	2026-10-21 23:42:57.400099+07
2448	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	233	75	0	2026-10-21 23:43:04.381+07	2026-10-21 23:43:04.385031+07
2449	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	247	75	0	2026-10-21 23:43:04.381+07	2026-10-21 23:43:04.38672+07
2456	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	243	75	0	2026-10-21 23:43:18.385+07	2026-10-21 23:43:18.397789+07
2457	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	248	75	0	2026-10-21 23:43:18.384+07	2026-10-21 23:43:18.401728+07
2460	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	243	75	0	2026-10-21 23:43:25.378+07	2026-10-21 23:43:25.384236+07
2461	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	237	75	0	2026-10-21 23:43:25.377+07	2026-10-21 23:43:25.387558+07
2466	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	231	75	0	2026-10-21 23:43:35.871+07	2026-10-21 23:43:35.879239+07
2467	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	243	75	0	2026-10-21 23:43:35.871+07	2026-10-21 23:43:35.88386+07
2472	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	242	75	0	2026-10-21 23:43:46.38+07	2026-10-21 23:43:46.387006+07
2473	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	228	75	0	2026-10-21 23:43:46.38+07	2026-10-21 23:43:46.389953+07
2474	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	238	75	0	2026-10-21 23:43:49.873+07	2026-10-21 23:43:49.87839+07
2475	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	231	75	0	2026-10-21 23:43:49.873+07	2026-10-21 23:43:49.882643+07
2478	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	37	0	5.67	2026-10-21 23:43:54.308+07	2026-10-21 23:43:56.876006+07
2479	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	237	75	0	2026-10-21 23:43:56.871+07	2026-10-21 23:43:56.878482+07
2482	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	235	75	0	2026-10-21 23:44:01.376+07	2026-10-21 23:44:01.38029+07
2483	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	231	75	0	2026-10-21 23:44:01.376+07	2026-10-21 23:44:01.382065+07
2486	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	253	75	0	2026-10-21 23:44:08.38+07	2026-10-21 23:44:08.383855+07
2487	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	250	75	0	2026-10-21 23:44:08.38+07	2026-10-21 23:44:08.385545+07
2490	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	229	75	0	2026-10-21 23:44:15.377+07	2026-10-21 23:44:15.381364+07
2491	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	215	75	0	2026-10-21 23:44:15.377+07	2026-10-21 23:44:15.382794+07
2494	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	243	75	0	2026-10-21 23:44:22.38+07	2026-10-21 23:44:22.384834+07
2495	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	236	75	0	2026-10-21 23:44:22.38+07	2026-10-21 23:44:22.38652+07
2498	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	229	75	0	2026-10-21 23:44:29.372+07	2026-10-21 23:44:29.884571+07
2499	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 23:44:29.881+07	2026-10-21 23:44:29.88618+07
2500	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	235	75	0	2026-10-21 23:44:33.376+07	2026-10-21 23:44:33.380188+07
2501	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	243	75	0	2026-10-21 23:44:33.376+07	2026-10-21 23:44:33.381737+07
2504	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	46	0	17.33	2026-10-21 23:44:35.45+07	2026-10-21 23:44:35.45331+07
2505	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	43	0	12	2026-10-21 23:44:35.45+07	2026-10-21 23:44:35.454924+07
2508	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	66	0	31.33	2026-10-21 23:44:39.936+07	2026-10-21 23:44:42.383914+07
2509	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	240	75	0	2026-10-21 23:44:42.38+07	2026-10-21 23:44:42.385349+07
2868	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	233	75	0	2026-10-22 00:27:52.876+07	2026-10-22 00:27:52.896222+07
2869	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	241	75	0	2026-10-22 00:27:52.876+07	2026-10-22 00:27:52.92406+07
2872	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	230	75	0	2026-10-22 00:27:59.88+07	2026-10-22 00:27:59.89211+07
2873	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	244	75	0	2026-10-22 00:27:59.88+07	2026-10-22 00:27:59.897659+07
2876	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	234	75	0	2026-10-22 00:28:06.886+07	2026-10-22 00:28:06.896714+07
2877	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	246	75	0	2026-10-22 00:28:06.886+07	2026-10-22 00:28:06.903032+07
2880	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	242	75	0	2026-10-22 00:28:13.871+07	2026-10-22 00:28:13.878414+07
2881	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	232	75	0	2026-10-22 00:28:13.871+07	2026-10-22 00:28:13.882099+07
2882	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	58	0	18.33	2026-10-22 00:28:14.904+07	2026-10-22 00:28:17.378075+07
2883	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	238	75	0	2026-10-22 00:28:17.373+07	2026-10-22 00:28:17.38034+07
2884	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	242	75	0	2026-10-22 00:28:20.867+07	2026-10-22 00:28:20.871733+07
2885	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	232	75	0	2026-10-22 00:28:20.867+07	2026-10-22 00:28:20.873303+07
2888	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	235	75	0	2026-10-22 00:28:27.873+07	2026-10-22 00:28:27.879921+07
2889	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	239	75	0	2026-10-22 00:28:27.872+07	2026-10-22 00:28:27.884224+07
2894	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	236	75	0	2026-10-22 00:28:38.379+07	2026-10-22 00:28:38.385107+07
2895	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	232	75	0	2026-10-22 00:28:38.379+07	2026-10-22 00:28:38.387013+07
2898	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	240	75	0	2026-10-22 00:28:45.376+07	2026-10-22 00:28:45.380748+07
2899	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	236	75	0	2026-10-22 00:28:45.376+07	2026-10-22 00:28:45.383013+07
2904	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	241	75	0	2026-10-22 00:28:55.881+07	2026-10-22 00:28:55.885513+07
2905	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	235	75	0	2026-10-22 00:28:55.881+07	2026-10-22 00:28:55.887157+07
2908	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	234	75	0	2026-10-22 00:29:02.878+07	2026-10-22 00:29:02.890334+07
2909	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	242	75	0	2026-10-22 00:29:02.878+07	2026-10-22 00:29:02.896226+07
2912	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	185	75	0	2026-10-22 00:29:09.874+07	2026-10-22 00:29:09.88003+07
2442	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	249	75	0	2026-10-21 23:42:53.882+07	2026-10-21 23:42:53.891371+07
2443	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	241	75	0	2026-10-21 23:42:53.882+07	2026-10-21 23:42:53.897229+07
2446	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	245	75	0	2026-10-21 23:43:00.869+07	2026-10-21 23:43:00.873103+07
2447	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	233	75	0	2026-10-21 23:43:00.869+07	2026-10-21 23:43:00.875414+07
2450	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	248	75	0	2026-10-21 23:43:07.879+07	2026-10-21 23:43:07.883797+07
2451	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	252	75	0	2026-10-21 23:43:07.879+07	2026-10-21 23:43:07.885957+07
2452	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	246	75	0	2026-10-21 23:43:11.374+07	2026-10-21 23:43:11.382287+07
2453	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	235	75	0	2026-10-21 23:43:11.374+07	2026-10-21 23:43:11.385783+07
2454	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	230	75	0	2026-10-21 23:43:14.874+07	2026-10-21 23:43:14.878877+07
2455	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	242	75	0	2026-10-21 23:43:14.874+07	2026-10-21 23:43:14.880569+07
2458	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	238	75	0	2026-10-21 23:43:21.87+07	2026-10-21 23:43:21.877459+07
2459	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	234	75	0	2026-10-21 23:43:21.87+07	2026-10-21 23:43:21.881148+07
2462	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	232	75	0	2026-10-21 23:43:28.875+07	2026-10-21 23:43:28.880335+07
2463	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	238	75	0	2026-10-21 23:43:28.875+07	2026-10-21 23:43:28.882432+07
2464	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	224	75	0	2026-10-21 23:43:32.375+07	2026-10-21 23:43:32.379109+07
2465	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	237	75	0	2026-10-21 23:43:32.375+07	2026-10-21 23:43:32.380603+07
2468	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	256	75	0	2026-10-21 23:43:39.38+07	2026-10-21 23:43:39.388544+07
2469	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	251	75	0	2026-10-21 23:43:39.38+07	2026-10-21 23:43:39.391971+07
2470	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	232	75	0	2026-10-21 23:43:42.869+07	2026-10-21 23:43:42.876131+07
2471	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	242	75	0	2026-10-21 23:43:42.869+07	2026-10-21 23:43:42.879849+07
2476	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	230	75	0	2026-10-21 23:43:53.369+07	2026-10-21 23:43:53.372653+07
2477	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	242	75	0	2026-10-21 23:43:53.369+07	2026-10-21 23:43:53.375183+07
2480	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	52	0	27.33	2026-10-21 23:43:57.858+07	2026-10-21 23:43:57.862513+07
2481	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	49	0	22.67	2026-10-21 23:43:57.852+07	2026-10-21 23:43:57.864557+07
2484	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	236	75	0	2026-10-21 23:44:04.871+07	2026-10-21 23:44:04.878016+07
2485	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	232	75	0	2026-10-21 23:44:04.871+07	2026-10-21 23:44:04.88006+07
2488	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	255	75	0	2026-10-21 23:44:11.876+07	2026-10-21 23:44:11.885067+07
2489	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	245	75	0	2026-10-21 23:44:11.876+07	2026-10-21 23:44:11.889242+07
2492	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	243	75	0	2026-10-21 23:44:18.875+07	2026-10-21 23:44:18.885599+07
2493	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	232	75	0	2026-10-21 23:44:18.875+07	2026-10-21 23:44:18.887848+07
2496	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	243	75	0	2026-10-21 23:44:25.871+07	2026-10-21 23:44:25.878481+07
2497	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	233	75	0	2026-10-21 23:44:25.87+07	2026-10-21 23:44:25.882078+07
2502	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	online	84	0	72	2026-10-21 23:44:34.476+07	2026-10-21 23:44:34.479593+07
2503	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	41	0	4.67	2026-10-21 23:44:34.327+07	2026-10-21 23:44:34.480953+07
2506	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	48	0	11.67	2026-10-21 23:44:36.427+07	2026-10-21 23:44:38.890725+07
2507	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	240	75	0	2026-10-21 23:44:38.883+07	2026-10-21 23:44:38.894432+07
2510	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	245	75	0	2026-10-21 23:44:45.884+07	2026-10-21 23:44:45.889999+07
2511	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	238	75	0	2026-10-21 23:44:45.884+07	2026-10-21 23:44:45.892742+07
2512	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	243	75	0	2026-10-21 23:47:56.383+07	2026-10-21 23:47:56.398312+07
2513	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	253	75	0	2026-10-21 23:51:03.384+07	2026-10-21 23:51:03.399577+07
2514	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-21 23:54:10.373+07	2026-10-21 23:54:10.382064+07
2515	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	223	75	0	2026-10-21 23:54:17.365+07	2026-10-21 23:54:17.369813+07
2516	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	220	75	0	2026-10-21 23:54:17.365+07	2026-10-21 23:54:17.372162+07
2517	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	739	75	0	2026-10-21 23:54:20.881+07	2026-10-21 23:54:20.88603+07
2518	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	744	75	0	2026-10-21 23:54:20.881+07	2026-10-21 23:54:20.887953+07
2519	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	744	75	0	2026-10-21 23:54:24.873+07	2026-10-21 23:54:24.878755+07
2520	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	740	75	0	2026-10-21 23:54:24.873+07	2026-10-21 23:54:24.88027+07
2521	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	735	75	0	2026-10-21 23:54:28.869+07	2026-10-21 23:54:28.879097+07
2522	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	739	75	0	2026-10-21 23:54:28.868+07	2026-10-21 23:54:28.882562+07
2523	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	235	75	0	2026-10-21 23:54:32.374+07	2026-10-21 23:54:32.379586+07
2524	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	239	75	0	2026-10-21 23:54:32.374+07	2026-10-21 23:54:32.381157+07
2525	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	240	75	0	2026-10-21 23:54:35.871+07	2026-10-21 23:54:35.87663+07
2526	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	230	75	0	2026-10-21 23:54:35.871+07	2026-10-21 23:54:35.879118+07
2527	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	238	75	0	2026-10-21 23:54:39.381+07	2026-10-21 23:54:39.38865+07
2528	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	241	75	0	2026-10-21 23:54:39.38+07	2026-10-21 23:54:39.392954+07
2529	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	242	75	0	2026-10-21 23:54:42.875+07	2026-10-21 23:54:42.879258+07
2530	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	231	75	0	2026-10-21 23:54:42.875+07	2026-10-21 23:54:42.880675+07
2531	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	70	0	19	2026-10-21 23:54:43.951+07	2026-10-21 23:54:46.393526+07
2532	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	243	75	0	2026-10-21 23:54:46.377+07	2026-10-21 23:54:46.398376+07
2533	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	227	75	0	2026-10-21 23:54:49.88+07	2026-10-21 23:54:49.890233+07
2534	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	237	75	0	2026-10-21 23:54:49.88+07	2026-10-21 23:54:49.896142+07
2535	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	65	0	28.33	2026-10-21 23:54:50.927+07	2026-10-21 23:54:53.376382+07
2536	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	243	75	0	2026-10-21 23:54:53.37+07	2026-10-21 23:54:53.379648+07
2539	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	245	75	0	2026-10-21 23:55:00.381+07	2026-10-21 23:55:00.385354+07
2540	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	240	75	0	2026-10-21 23:55:00.38+07	2026-10-21 23:55:00.387062+07
2543	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	242	75	0	2026-10-21 23:55:07.369+07	2026-10-21 23:55:07.374031+07
2544	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	238	75	0	2026-10-21 23:55:07.369+07	2026-10-21 23:55:07.375982+07
2545	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	239	75	0	2026-10-21 23:55:10.871+07	2026-10-21 23:55:10.875809+07
2546	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	244	75	0	2026-10-21 23:55:10.871+07	2026-10-21 23:55:10.877958+07
2547	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	240	75	0	2026-10-21 23:55:14.381+07	2026-10-21 23:55:14.386385+07
2548	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	244	75	0	2026-10-21 23:55:14.381+07	2026-10-21 23:55:14.388393+07
2549	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	228	75	0	2026-10-21 23:55:17.882+07	2026-10-21 23:55:17.887874+07
2550	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	239	75	0	2026-10-21 23:55:17.882+07	2026-10-21 23:55:17.891053+07
2551	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	245	75	0	2026-10-21 23:55:21.378+07	2026-10-21 23:55:21.382902+07
2552	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	241	75	0	2026-10-21 23:55:21.378+07	2026-10-21 23:55:21.384655+07
2553	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	242	75	0	2026-10-21 23:55:24.874+07	2026-10-21 23:55:24.879437+07
2554	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	236	75	0	2026-10-21 23:55:24.875+07	2026-10-21 23:55:24.881079+07
2555	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	241	75	0	2026-10-21 23:55:28.382+07	2026-10-21 23:55:28.388583+07
2556	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	245	75	0	2026-10-21 23:55:28.381+07	2026-10-21 23:55:28.393182+07
2559	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	237	75	0	2026-10-21 23:55:35.38+07	2026-10-21 23:55:35.38527+07
2560	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	233	75	0	2026-10-21 23:55:35.38+07	2026-10-21 23:55:35.387116+07
2561	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	239	75	0	2026-10-21 23:55:38.874+07	2026-10-21 23:55:38.878213+07
2562	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	215	75	0	2026-10-21 23:55:38.874+07	2026-10-21 23:55:38.879951+07
2563	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	232	75	0	2026-10-21 23:55:42.372+07	2026-10-21 23:55:42.377176+07
2564	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	237	75	0	2026-10-21 23:55:42.372+07	2026-10-21 23:55:42.378949+07
2565	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	233	75	0	2026-10-21 23:55:45.877+07	2026-10-21 23:55:45.881449+07
2566	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	237	75	0	2026-10-21 23:55:45.877+07	2026-10-21 23:55:45.883088+07
2567	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	234	75	0	2026-10-21 23:55:49.376+07	2026-10-21 23:55:49.381265+07
2568	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	239	75	0	2026-10-21 23:55:49.376+07	2026-10-21 23:55:49.382724+07
2569	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	233	75	0	2026-10-21 23:55:52.88+07	2026-10-21 23:55:52.884281+07
2570	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	238	75	0	2026-10-21 23:55:52.88+07	2026-10-21 23:55:52.885754+07
2573	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	246	75	0	2026-10-21 23:55:59.877+07	2026-10-21 23:55:59.886326+07
2574	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	236	75	0	2026-10-21 23:55:59.876+07	2026-10-21 23:55:59.890748+07
2585	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	241	75	0	2026-10-21 23:56:20.876+07	2026-10-21 23:56:20.880715+07
2586	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	229	75	0	2026-10-21 23:56:20.876+07	2026-10-21 23:56:20.882494+07
2589	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	237	75	0	2026-10-21 23:56:27.868+07	2026-10-21 23:56:27.876166+07
2590	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	225	75	0	2026-10-21 23:56:27.869+07	2026-10-21 23:56:27.882855+07
2597	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	39	0	6.33	2026-10-21 23:56:39.307+07	2026-10-21 23:56:41.882847+07
2598	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	237	75	0	2026-10-21 23:56:41.878+07	2026-10-21 23:56:41.884962+07
2601	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	239	75	0	2026-10-21 23:56:46.378+07	2026-10-21 23:56:46.382432+07
2602	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	235	75	0	2026-10-21 23:56:46.378+07	2026-10-21 23:56:46.384283+07
2603	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	226	75	0	2026-10-21 23:56:49.875+07	2026-10-21 23:56:49.881378+07
2604	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	239	75	0	2026-10-21 23:56:49.875+07	2026-10-21 23:56:49.884084+07
2605	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	233	75	0	2026-10-21 23:56:53.366+07	2026-10-21 23:56:53.371241+07
2606	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	237	75	0	2026-10-21 23:56:53.366+07	2026-10-21 23:56:53.373807+07
2607	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	234	75	0	2026-10-21 23:56:56.881+07	2026-10-21 23:56:56.886222+07
2608	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	244	75	0	2026-10-21 23:56:56.881+07	2026-10-21 23:56:56.88894+07
2870	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	214	75	0	2026-10-22 00:27:56.373+07	2026-10-22 00:27:56.383141+07
2871	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	225	75	0	2026-10-22 00:27:56.373+07	2026-10-22 00:27:56.386012+07
2874	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	240	75	0	2026-10-22 00:28:03.371+07	2026-10-22 00:28:03.375776+07
2875	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	230	75	0	2026-10-22 00:28:03.371+07	2026-10-22 00:28:03.378056+07
2878	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	238	75	0	2026-10-22 00:28:10.379+07	2026-10-22 00:28:10.383579+07
2879	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	225	75	0	2026-10-22 00:28:10.379+07	2026-10-22 00:28:10.38515+07
2886	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	39	0	15.67	2026-10-22 00:28:21.822+07	2026-10-22 00:28:24.384701+07
2887	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	242	75	0	2026-10-22 00:28:24.381+07	2026-10-22 00:28:24.386164+07
2890	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	237	75	0	2026-10-22 00:28:31.38+07	2026-10-22 00:28:31.385092+07
2537	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	230	75	0	2026-10-21 23:54:56.87+07	2026-10-21 23:54:56.874632+07
2538	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	243	75	0	2026-10-21 23:54:56.87+07	2026-10-21 23:54:56.877485+07
2541	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	240	75	0	2026-10-21 23:55:03.869+07	2026-10-21 23:55:03.875741+07
2542	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	236	75	0	2026-10-21 23:55:03.87+07	2026-10-21 23:55:03.878367+07
2557	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	234	75	0	2026-10-21 23:55:31.878+07	2026-10-21 23:55:31.882474+07
2558	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	242	75	0	2026-10-21 23:55:31.878+07	2026-10-21 23:55:31.883986+07
2571	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	233	75	0	2026-10-21 23:55:56.381+07	2026-10-21 23:55:56.389204+07
2572	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	237	75	0	2026-10-21 23:55:56.381+07	2026-10-21 23:55:56.392955+07
2575	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	239	75	0	2026-10-21 23:56:03.38+07	2026-10-21 23:56:03.385022+07
2576	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	242	75	0	2026-10-21 23:56:03.38+07	2026-10-21 23:56:03.386587+07
2577	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	254	75	0	2026-10-21 23:56:06.874+07	2026-10-21 23:56:06.878315+07
2578	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	249	75	0	2026-10-21 23:56:06.874+07	2026-10-21 23:56:06.879987+07
2579	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	245	75	0	2026-10-21 23:56:10.375+07	2026-10-21 23:56:10.379318+07
2580	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	240	75	0	2026-10-21 23:56:10.375+07	2026-10-21 23:56:10.381188+07
2581	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	233	75	0	2026-10-21 23:56:13.879+07	2026-10-21 23:56:13.886715+07
2582	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	242	75	0	2026-10-21 23:56:13.88+07	2026-10-21 23:56:13.891216+07
2583	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	227	75	0	2026-10-21 23:56:17.371+07	2026-10-21 23:56:17.37679+07
2584	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	224	75	0	2026-10-21 23:56:17.371+07	2026-10-21 23:56:17.378523+07
2587	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	239	75	0	2026-10-21 23:56:24.373+07	2026-10-21 23:56:24.379579+07
2588	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	242	75	0	2026-10-21 23:56:24.374+07	2026-10-21 23:56:24.381958+07
2591	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	237	75	0	2026-10-21 23:56:31.377+07	2026-10-21 23:56:31.381616+07
2592	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	240	75	0	2026-10-21 23:56:31.377+07	2026-10-21 23:56:31.383275+07
2593	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	234	75	0	2026-10-21 23:56:34.866+07	2026-10-21 23:56:34.870188+07
2594	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	238	75	0	2026-10-21 23:56:34.866+07	2026-10-21 23:56:34.871804+07
2595	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	236	75	0	2026-10-21 23:56:38.37+07	2026-10-21 23:56:38.374624+07
2596	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	242	75	0	2026-10-21 23:56:38.37+07	2026-10-21 23:56:38.37654+07
2599	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	49	0	21.33	2026-10-21 23:56:42.881+07	2026-10-21 23:56:42.885709+07
2600	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	49	0	26.67	2026-10-21 23:56:42.875+07	2026-10-21 23:56:42.887771+07
2609	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	238	75	0	2026-10-21 23:57:00.376+07	2026-10-21 23:57:00.381671+07
2610	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	242	75	0	2026-10-21 23:57:00.376+07	2026-10-21 23:57:00.394019+07
2611	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	238	75	0	2026-10-21 23:57:03.88+07	2026-10-21 23:57:03.885626+07
2612	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	233	75	0	2026-10-21 23:57:03.88+07	2026-10-21 23:57:03.887329+07
2613	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	243	75	0	2026-10-21 23:57:07.374+07	2026-10-21 23:57:07.379272+07
2614	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	239	75	0	2026-10-21 23:57:07.374+07	2026-10-21 23:57:07.381258+07
2615	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	232	75	0	2026-10-21 23:57:10.866+07	2026-10-21 23:57:10.870097+07
2616	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	236	75	0	2026-10-21 23:57:10.866+07	2026-10-21 23:57:10.872237+07
2617	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	237	75	0	2026-10-21 23:57:14.374+07	2026-10-21 23:57:14.878618+07
2618	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-21 23:57:14.874+07	2026-10-21 23:57:14.88051+07
2619	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	237	75	0	2026-10-21 23:57:18.376+07	2026-10-21 23:57:18.380311+07
2620	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	233	75	0	2026-10-21 23:57:18.376+07	2026-10-21 23:57:18.382719+07
2621	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	online	80	0	78.67	2026-10-21 23:57:19.485+07	2026-10-21 23:57:19.490437+07
2622	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	50	0	12.33	2026-10-21 23:57:19.364+07	2026-10-21 23:57:19.492174+07
2623	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	49	0	5.67	2026-10-21 23:57:20.478+07	2026-10-21 23:57:20.483525+07
2624	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	48	0	5	2026-10-21 23:57:20.479+07	2026-10-21 23:57:20.485098+07
2625	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	40	0	3	2026-10-21 23:57:21.418+07	2026-10-21 23:57:23.884603+07
2626	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	240	75	0	2026-10-21 23:57:23.879+07	2026-10-21 23:57:23.887575+07
2627	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	40	0	1.67	2026-10-21 23:57:24.824+07	2026-10-21 23:57:27.373609+07
2628	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	238	75	0	2026-10-21 23:57:27.368+07	2026-10-21 23:57:27.375683+07
2629	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	238	75	0	2026-10-21 23:57:30.88+07	2026-10-21 23:57:30.885719+07
2630	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	232	75	0	2026-10-21 23:57:30.88+07	2026-10-21 23:57:30.888685+07
2631	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	117	0	48.33	2026-10-22 00:00:19.616+07	2026-10-22 00:00:21.88448+07
2632	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-22 00:00:40.87+07	2026-10-22 00:00:40.873947+07
2633	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 00:03:41.377+07	2026-10-22 00:03:41.387094+07
2634	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	226	75	0	2026-10-22 00:03:48.868+07	2026-10-22 00:03:48.874559+07
2635	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	218	75	0	2026-10-22 00:03:48.868+07	2026-10-22 00:03:48.876524+07
2636	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	258	75	0	2026-10-22 00:03:52.375+07	2026-10-22 00:03:52.390299+07
2637	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	249	75	0	2026-10-22 00:03:52.375+07	2026-10-22 00:03:52.394092+07
2638	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	213	75	0	2026-10-22 00:03:55.874+07	2026-10-22 00:03:55.878498+07
2639	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	238	75	0	2026-10-22 00:03:55.874+07	2026-10-22 00:03:55.880962+07
2644	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	238	75	0	2026-10-22 00:04:06.369+07	2026-10-22 00:04:06.374956+07
2645	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	246	75	0	2026-10-22 00:04:06.369+07	2026-10-22 00:04:06.3782+07
2648	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	56	0	21	2026-10-22 00:04:10.888+07	2026-10-22 00:04:13.374395+07
2649	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	237	75	0	2026-10-22 00:04:13.369+07	2026-10-22 00:04:13.377129+07
2654	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	240	75	0	2026-10-22 00:04:23.888+07	2026-10-22 00:04:23.898569+07
2655	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	229	75	0	2026-10-22 00:04:23.888+07	2026-10-22 00:04:23.903515+07
2658	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	242	75	0	2026-10-22 00:04:30.876+07	2026-10-22 00:04:30.881471+07
2659	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	237	75	0	2026-10-22 00:04:30.876+07	2026-10-22 00:04:30.883357+07
2662	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	236	75	0	2026-10-22 00:04:37.88+07	2026-10-22 00:04:37.884398+07
2663	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	243	75	0	2026-10-22 00:04:37.88+07	2026-10-22 00:04:37.886053+07
2891	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	226	75	0	2026-10-22 00:28:31.38+07	2026-10-22 00:28:31.386707+07
2892	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	242	75	0	2026-10-22 00:28:34.879+07	2026-10-22 00:28:34.883332+07
2893	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	228	75	0	2026-10-22 00:28:34.879+07	2026-10-22 00:28:34.884915+07
2896	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	235	75	0	2026-10-22 00:28:41.871+07	2026-10-22 00:28:41.875561+07
2897	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	246	75	0	2026-10-22 00:28:41.871+07	2026-10-22 00:28:41.877602+07
2900	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	227	75	0	2026-10-22 00:28:48.876+07	2026-10-22 00:28:48.882645+07
2901	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	238	75	0	2026-10-22 00:28:48.875+07	2026-10-22 00:28:48.885589+07
2902	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	230	75	0	2026-10-22 00:28:52.37+07	2026-10-22 00:28:52.374639+07
2903	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	242	75	0	2026-10-22 00:28:52.37+07	2026-10-22 00:28:52.377114+07
2906	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	229	75	0	2026-10-22 00:28:59.377+07	2026-10-22 00:28:59.383332+07
2907	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	241	75	0	2026-10-22 00:28:59.377+07	2026-10-22 00:28:59.386293+07
2910	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	244	75	0	2026-10-22 00:29:06.378+07	2026-10-22 00:29:06.381512+07
2911	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	232	75	0	2026-10-22 00:29:06.378+07	2026-10-22 00:29:06.383055+07
2914	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	228	75	0	2026-10-22 00:29:13.38+07	2026-10-22 00:29:13.384113+07
2915	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	239	75	0	2026-10-22 00:29:13.38+07	2026-10-22 00:29:13.386039+07
2920	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	231	75	0	2026-10-22 00:29:23.879+07	2026-10-22 00:29:23.883066+07
2921	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	242	75	0	2026-10-22 00:29:23.879+07	2026-10-22 00:29:23.884615+07
2924	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	244	75	0	2026-10-22 00:29:30.869+07	2026-10-22 00:29:30.873506+07
2925	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	236	75	0	2026-10-22 00:29:30.869+07	2026-10-22 00:29:30.876135+07
2928	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	234	75	0	2026-10-22 00:29:37.879+07	2026-10-22 00:29:37.884943+07
2929	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	244	75	0	2026-10-22 00:29:37.879+07	2026-10-22 00:29:37.887611+07
2932	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	232	75	0	2026-10-22 00:29:44.876+07	2026-10-22 00:29:44.881475+07
2933	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	242	75	0	2026-10-22 00:29:44.876+07	2026-10-22 00:29:44.883737+07
2934	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	243	75	0	2026-10-22 00:29:48.379+07	2026-10-22 00:29:48.382882+07
2935	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	254	75	0	2026-10-22 00:29:48.379+07	2026-10-22 00:29:48.384755+07
2938	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	250	75	0	2026-10-22 00:29:55.375+07	2026-10-22 00:29:55.379863+07
2939	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	253	75	0	2026-10-22 00:29:55.375+07	2026-10-22 00:29:55.38164+07
3099	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-22 00:41:15.375+07	2026-10-22 00:41:15.383681+07
3187	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	40	0	13.33	2026-10-22 00:50:38.845+07	2026-10-22 00:50:38.857254+07
3190	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	236	75	0	2026-10-22 00:50:45.88+07	2026-10-22 00:50:45.884652+07
3191	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	225	75	0	2026-10-22 00:50:45.88+07	2026-10-22 00:50:45.886179+07
3196	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	223	75	0	2026-10-22 00:50:56.373+07	2026-10-22 00:50:56.377966+07
3197	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	220	75	0	2026-10-22 00:50:56.373+07	2026-10-22 00:50:56.379846+07
3200	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	218	75	0	2026-10-22 00:51:03.37+07	2026-10-22 00:51:03.374397+07
3201	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	222	75	0	2026-10-22 00:51:03.37+07	2026-10-22 00:51:03.376599+07
3202	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	224	75	0	2026-10-22 00:51:06.87+07	2026-10-22 00:51:06.8748+07
3203	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	219	75	0	2026-10-22 00:51:06.87+07	2026-10-22 00:51:06.876794+07
3222	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	243	75	0	2026-10-22 01:01:02.368+07	2026-10-22 01:01:02.376985+07
3238	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	232	75	0	2026-10-22 01:15:11.873+07	2026-10-22 01:15:11.880089+07
3239	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	238	75	0	2026-10-22 01:15:11.873+07	2026-10-22 01:15:11.882063+07
3242	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	236	75	0	2026-10-22 01:15:18.876+07	2026-10-22 01:15:18.88123+07
3243	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	238	75	0	2026-10-22 01:15:18.876+07	2026-10-22 01:15:18.883475+07
3244	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	62	0	34.33	2026-10-22 01:15:19.905+07	2026-10-22 01:15:22.38181+07
3245	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	244	75	0	2026-10-22 01:15:22.378+07	2026-10-22 01:15:22.38327+07
3248	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	63	0	41	2026-10-22 01:15:26.945+07	2026-10-22 01:15:29.375864+07
3249	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	241	75	0	2026-10-22 01:15:29.37+07	2026-10-22 01:15:29.378911+07
3304	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	221	75	0	2026-10-22 01:17:07.381+07	2026-10-22 01:17:07.393721+07
2640	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	240	75	0	2026-10-22 00:03:59.386+07	2026-10-22 00:03:59.413363+07
2641	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	243	75	0	2026-10-22 00:03:59.401+07	2026-10-22 00:03:59.419406+07
2642	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	244	75	0	2026-10-22 00:04:02.878+07	2026-10-22 00:04:02.884345+07
2643	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	235	75	0	2026-10-22 00:04:02.878+07	2026-10-22 00:04:02.886386+07
2646	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	241	75	0	2026-10-22 00:04:09.87+07	2026-10-22 00:04:09.875534+07
2647	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	232	75	0	2026-10-22 00:04:09.87+07	2026-10-22 00:04:09.878462+07
2650	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	243	75	0	2026-10-22 00:04:16.872+07	2026-10-22 00:04:16.88297+07
2651	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	231	75	0	2026-10-22 00:04:16.872+07	2026-10-22 00:04:16.886927+07
2652	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	56	0	10.67	2026-10-22 00:04:17.889+07	2026-10-22 00:04:20.37583+07
2653	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	238	75	0	2026-10-22 00:04:20.372+07	2026-10-22 00:04:20.377458+07
2656	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	233	75	0	2026-10-22 00:04:27.373+07	2026-10-22 00:04:27.378548+07
2657	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	238	75	0	2026-10-22 00:04:27.373+07	2026-10-22 00:04:27.38117+07
2660	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	228	75	0	2026-10-22 00:04:34.375+07	2026-10-22 00:04:34.380083+07
2661	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	241	75	0	2026-10-22 00:04:34.375+07	2026-10-22 00:04:34.382092+07
2664	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	233	75	0	2026-10-22 00:04:41.374+07	2026-10-22 00:04:41.384945+07
2665	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	245	75	0	2026-10-22 00:04:41.375+07	2026-10-22 00:04:41.389708+07
2666	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	239	75	0	2026-10-22 00:04:44.879+07	2026-10-22 00:04:44.895841+07
2667	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	228	75	0	2026-10-22 00:04:44.879+07	2026-10-22 00:04:44.900892+07
2668	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	236	75	0	2026-10-22 00:04:48.367+07	2026-10-22 00:04:48.372504+07
2669	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	244	75	0	2026-10-22 00:04:48.367+07	2026-10-22 00:04:48.374765+07
2670	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	238	75	0	2026-10-22 00:04:51.882+07	2026-10-22 00:04:51.887948+07
2671	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	233	75	0	2026-10-22 00:04:51.882+07	2026-10-22 00:04:51.890457+07
2672	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	240	75	0	2026-10-22 00:04:55.367+07	2026-10-22 00:04:55.373315+07
2673	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	244	75	0	2026-10-22 00:04:55.367+07	2026-10-22 00:04:55.375876+07
2674	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	232	75	0	2026-10-22 00:04:58.875+07	2026-10-22 00:04:58.887423+07
2675	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	242	75	0	2026-10-22 00:04:58.875+07	2026-10-22 00:04:58.892281+07
2676	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	238	75	0	2026-10-22 00:05:02.376+07	2026-10-22 00:05:02.380756+07
2677	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	243	75	0	2026-10-22 00:05:02.376+07	2026-10-22 00:05:02.382399+07
2678	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	243	75	0	2026-10-22 00:05:05.869+07	2026-10-22 00:05:05.874414+07
2679	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	237	75	0	2026-10-22 00:05:05.869+07	2026-10-22 00:05:05.877484+07
2680	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	236	75	0	2026-10-22 00:05:09.374+07	2026-10-22 00:05:09.383157+07
2681	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	245	75	0	2026-10-22 00:05:09.374+07	2026-10-22 00:05:09.389285+07
2682	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	244	75	0	2026-10-22 00:05:12.884+07	2026-10-22 00:05:12.899147+07
2683	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	238	75	0	2026-10-22 00:05:12.884+07	2026-10-22 00:05:12.902583+07
2684	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	234	75	0	2026-10-22 00:05:16.38+07	2026-10-22 00:05:16.387117+07
2685	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	238	75	0	2026-10-22 00:05:16.38+07	2026-10-22 00:05:16.390123+07
2686	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	236	75	0	2026-10-22 00:05:19.873+07	2026-10-22 00:05:19.882737+07
2687	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	241	75	0	2026-10-22 00:05:19.873+07	2026-10-22 00:05:19.885681+07
2688	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	237	75	0	2026-10-22 00:05:23.382+07	2026-10-22 00:05:23.389727+07
2689	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	242	75	0	2026-10-22 00:05:23.381+07	2026-10-22 00:05:23.393056+07
2690	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	230	75	0	2026-10-22 00:05:26.876+07	2026-10-22 00:05:26.890571+07
2691	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	240	75	0	2026-10-22 00:05:26.875+07	2026-10-22 00:05:26.894507+07
2692	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	234	75	0	2026-10-22 00:05:30.381+07	2026-10-22 00:05:30.388313+07
2693	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	237	75	0	2026-10-22 00:05:30.381+07	2026-10-22 00:05:30.391529+07
2694	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	237	75	0	2026-10-22 00:05:33.873+07	2026-10-22 00:05:33.881042+07
2695	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	233	75	0	2026-10-22 00:05:33.873+07	2026-10-22 00:05:33.884683+07
2696	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	234	75	0	2026-10-22 00:05:37.382+07	2026-10-22 00:05:37.393048+07
2697	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	242	75	0	2026-10-22 00:05:37.383+07	2026-10-22 00:05:37.400283+07
2698	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	242	75	0	2026-10-22 00:05:40.873+07	2026-10-22 00:05:40.880188+07
2699	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	237	75	0	2026-10-22 00:05:40.873+07	2026-10-22 00:05:40.882701+07
2700	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	229	75	0	2026-10-22 00:05:44.376+07	2026-10-22 00:05:44.385591+07
2701	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	241	75	0	2026-10-22 00:05:44.375+07	2026-10-22 00:05:44.388012+07
2702	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	235	75	0	2026-10-22 00:05:47.872+07	2026-10-22 00:05:47.878866+07
2703	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	241	75	0	2026-10-22 00:05:47.872+07	2026-10-22 00:05:47.881804+07
2704	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	240	75	0	2026-10-22 00:05:51.371+07	2026-10-22 00:05:51.377699+07
2705	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	228	75	0	2026-10-22 00:05:51.371+07	2026-10-22 00:05:51.381675+07
2706	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	243	75	0	2026-10-22 00:05:54.882+07	2026-10-22 00:05:54.900357+07
2707	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	232	75	0	2026-10-22 00:05:54.882+07	2026-10-22 00:05:54.905924+07
2708	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	233	75	0	2026-10-22 00:05:58.366+07	2026-10-22 00:05:58.369893+07
2709	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	236	75	0	2026-10-22 00:05:58.366+07	2026-10-22 00:05:58.371478+07
2710	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	238	75	0	2026-10-22 00:06:01.873+07	2026-10-22 00:06:01.877467+07
2711	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	234	75	0	2026-10-22 00:06:01.873+07	2026-10-22 00:06:01.879673+07
2712	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	238	75	0	2026-10-22 00:06:05.379+07	2026-10-22 00:06:05.385225+07
2713	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	246	75	0	2026-10-22 00:06:05.379+07	2026-10-22 00:06:05.388863+07
2714	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	52	0	15.33	2026-10-22 00:06:06.448+07	2026-10-22 00:06:08.892901+07
2715	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	210	75	0	2026-10-22 00:06:08.878+07	2026-10-22 00:06:08.89608+07
2913	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	221	75	0	2026-10-22 00:29:09.874+07	2026-10-22 00:29:09.882782+07
2916	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	232	75	0	2026-10-22 00:29:16.881+07	2026-10-22 00:29:16.888682+07
2917	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	244	75	0	2026-10-22 00:29:16.881+07	2026-10-22 00:29:16.893106+07
2918	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	230	75	0	2026-10-22 00:29:20.371+07	2026-10-22 00:29:20.374607+07
2919	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	242	75	0	2026-10-22 00:29:20.371+07	2026-10-22 00:29:20.376425+07
2922	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	234	75	0	2026-10-22 00:29:27.379+07	2026-10-22 00:29:27.38304+07
2923	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	245	75	0	2026-10-22 00:29:27.379+07	2026-10-22 00:29:27.384879+07
2926	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	229	75	0	2026-10-22 00:29:34.377+07	2026-10-22 00:29:34.381879+07
2927	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	242	75	0	2026-10-22 00:29:34.377+07	2026-10-22 00:29:34.383435+07
2930	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	227	75	0	2026-10-22 00:29:41.377+07	2026-10-22 00:29:41.381545+07
2931	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	237	75	0	2026-10-22 00:29:41.378+07	2026-10-22 00:29:41.382951+07
2936	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	232	75	0	2026-10-22 00:29:51.881+07	2026-10-22 00:29:51.890941+07
2937	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	243	75	0	2026-10-22 00:29:51.881+07	2026-10-22 00:29:51.896124+07
3100	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	256	75	0	2026-10-22 00:44:22.38+07	2026-10-22 00:44:22.39356+07
3193	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	213	75	0	2026-10-22 00:50:49.372+07	2026-10-22 00:50:49.378902+07
3194	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	230	75	0	2026-10-22 00:50:52.87+07	2026-10-22 00:50:52.874215+07
3195	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	241	75	0	2026-10-22 00:50:52.87+07	2026-10-22 00:50:52.875628+07
3204	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	262	75	0	2026-10-22 00:51:10.374+07	2026-10-22 00:51:10.877353+07
3205	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 00:51:10.873+07	2026-10-22 00:51:10.87921+07
3208	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 00:51:18.378+07	2026-10-22 00:51:18.386759+07
3209	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	51	0	21.67	2026-10-22 00:51:15.403+07	2026-10-22 00:51:18.390105+07
3214	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	35	0	4	2026-10-22 00:51:23.809+07	2026-10-22 00:51:26.375982+07
3215	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	243	75	0	2026-10-22 00:51:26.371+07	2026-10-22 00:51:26.378978+07
3223	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	233	75	0	2026-10-22 01:04:09.882+07	2026-10-22 01:04:09.890187+07
3252	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	223	75	0	2026-10-22 01:15:36.37+07	2026-10-22 01:15:36.378867+07
3253	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	211	75	0	2026-10-22 01:15:36.371+07	2026-10-22 01:15:36.381245+07
3256	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	231	75	0	2026-10-22 01:15:43.38+07	2026-10-22 01:15:43.387693+07
3257	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	243	75	0	2026-10-22 01:15:43.38+07	2026-10-22 01:15:43.391456+07
3258	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	238	75	0	2026-10-22 01:15:46.867+07	2026-10-22 01:15:46.872033+07
3259	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	235	75	0	2026-10-22 01:15:46.867+07	2026-10-22 01:15:46.874494+07
3264	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	235	75	0	2026-10-22 01:15:57.371+07	2026-10-22 01:15:57.382257+07
3265	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	244	75	0	2026-10-22 01:15:57.371+07	2026-10-22 01:15:57.385823+07
3272	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	237	75	0	2026-10-22 01:16:11.372+07	2026-10-22 01:16:11.381302+07
3273	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	226	75	0	2026-10-22 01:16:11.373+07	2026-10-22 01:16:11.384515+07
3278	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	236	75	0	2026-10-22 01:16:21.879+07	2026-10-22 01:16:21.883723+07
3279	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	239	75	0	2026-10-22 01:16:21.879+07	2026-10-22 01:16:21.885292+07
3286	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	227	75	0	2026-10-22 01:16:35.877+07	2026-10-22 01:16:35.885552+07
3287	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	222	75	0	2026-10-22 01:16:35.877+07	2026-10-22 01:16:35.888684+07
3294	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	240	75	0	2026-10-22 01:16:49.869+07	2026-10-22 01:16:49.877447+07
3295	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	246	75	0	2026-10-22 01:16:49.87+07	2026-10-22 01:16:49.881056+07
3296	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	244	75	0	2026-10-22 01:16:53.383+07	2026-10-22 01:16:53.392913+07
3297	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	235	75	0	2026-10-22 01:16:53.383+07	2026-10-22 01:16:53.396431+07
3298	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	237	75	0	2026-10-22 01:16:56.877+07	2026-10-22 01:16:56.882745+07
3299	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	240	75	0	2026-10-22 01:16:56.877+07	2026-10-22 01:16:56.884843+07
3305	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	232	75	0	2026-10-22 01:17:07.381+07	2026-10-22 01:17:07.39862+07
3306	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	240	75	0	2026-10-22 01:17:10.881+07	2026-10-22 01:17:10.886691+07
3307	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	236	75	0	2026-10-22 01:17:10.881+07	2026-10-22 01:17:10.889272+07
3308	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	238	75	0	2026-10-22 01:17:14.373+07	2026-10-22 01:17:14.378831+07
3309	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	243	75	0	2026-10-22 01:17:14.373+07	2026-10-22 01:17:14.38034+07
3312	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	50	0	15	2026-10-22 01:17:18.853+07	2026-10-22 01:17:18.857065+07
2716	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	57	0	18.33	2026-10-22 00:06:09.911+07	2026-10-22 00:06:09.915894+07
2717	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	44	0	15.67	2026-10-22 00:06:09.912+07	2026-10-22 00:06:09.917296+07
2718	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	234	75	0	2026-10-22 00:06:13.385+07	2026-10-22 00:06:13.397064+07
2719	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	238	75	0	2026-10-22 00:06:13.385+07	2026-10-22 00:06:13.401906+07
2720	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	239	75	0	2026-10-22 00:06:16.88+07	2026-10-22 00:06:16.887061+07
2721	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	245	75	0	2026-10-22 00:06:16.881+07	2026-10-22 00:06:16.890334+07
2722	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	244	75	0	2026-10-22 00:06:20.367+07	2026-10-22 00:06:20.37084+07
2723	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	232	75	0	2026-10-22 00:06:20.367+07	2026-10-22 00:06:20.372438+07
2724	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	241	75	0	2026-10-22 00:06:23.878+07	2026-10-22 00:06:23.88781+07
2725	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	233	75	0	2026-10-22 00:06:23.878+07	2026-10-22 00:06:23.894528+07
2726	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	232	75	0	2026-10-22 00:06:27.377+07	2026-10-22 00:06:27.389952+07
2727	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	244	75	0	2026-10-22 00:06:27.377+07	2026-10-22 00:06:27.394551+07
2728	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	244	75	0	2026-10-22 00:06:30.879+07	2026-10-22 00:06:30.883412+07
2729	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	235	75	0	2026-10-22 00:06:30.879+07	2026-10-22 00:06:30.885449+07
2730	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	232	75	0	2026-10-22 00:06:34.383+07	2026-10-22 00:06:34.399604+07
2731	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	237	75	0	2026-10-22 00:06:34.383+07	2026-10-22 00:06:34.404585+07
2732	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	234	75	0	2026-10-22 00:06:37.885+07	2026-10-22 00:06:37.891698+07
2733	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	240	75	0	2026-10-22 00:06:37.885+07	2026-10-22 00:06:37.893671+07
2734	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	245	75	0	2026-10-22 00:06:41.418+07	2026-10-22 00:06:41.877484+07
2735	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 00:06:41.872+07	2026-10-22 00:06:41.879741+07
2736	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	218	75	0	2026-10-22 00:06:45.388+07	2026-10-22 00:06:45.400963+07
2737	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	226	75	0	2026-10-22 00:06:45.388+07	2026-10-22 00:06:45.409903+07
2738	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 00:06:49.367+07	2026-10-22 00:06:49.371229+07
2739	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	50	0	7.67	2026-10-22 00:06:46.406+07	2026-10-22 00:06:49.372872+07
2740	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	51	0	26	2026-10-22 00:06:50.354+07	2026-10-22 00:06:50.371013+07
2741	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	52	0	19.33	2026-10-22 00:06:50.364+07	2026-10-22 00:06:50.37395+07
2742	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	44	0	25	2026-10-22 00:06:51.325+07	2026-10-22 00:06:53.882406+07
2743	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	242	75	0	2026-10-22 00:06:53.878+07	2026-10-22 00:06:53.884023+07
2744	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	50	0	19	2026-10-22 00:06:54.862+07	2026-10-22 00:06:57.379981+07
2745	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	222	75	0	2026-10-22 00:06:57.369+07	2026-10-22 00:06:57.385656+07
2746	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	254	75	0	2026-10-22 00:07:00.883+07	2026-10-22 00:07:00.887062+07
2747	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	242	75	0	2026-10-22 00:07:00.883+07	2026-10-22 00:07:00.888594+07
2748	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-22 00:10:11.373+07	2026-10-22 00:10:11.381246+07
2749	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	228	75	0	2026-10-22 00:12:41.379+07	2026-10-22 00:12:41.387567+07
2750	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	239	75	0	2026-10-22 00:12:41.379+07	2026-10-22 00:12:41.389907+07
2751	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-22 00:12:44.366+07	2026-10-22 00:12:44.370119+07
2752	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	230	75	0	2026-10-22 00:12:44.366+07	2026-10-22 00:12:44.371605+07
2753	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	223	75	0	2026-10-22 00:12:47.88+07	2026-10-22 00:12:47.884977+07
2754	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	212	75	0	2026-10-22 00:12:47.88+07	2026-10-22 00:12:47.887119+07
2755	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	227	75	0	2026-10-22 00:12:51.38+07	2026-10-22 00:12:51.384242+07
2756	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	240	75	0	2026-10-22 00:12:51.38+07	2026-10-22 00:12:51.386498+07
2757	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	242	75	0	2026-10-22 00:12:54.875+07	2026-10-22 00:12:54.884434+07
2758	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	229	75	0	2026-10-22 00:12:54.875+07	2026-10-22 00:12:54.889792+07
2759	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	228	75	0	2026-10-22 00:12:58.369+07	2026-10-22 00:12:58.375127+07
2760	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	240	75	0	2026-10-22 00:12:58.37+07	2026-10-22 00:12:58.376761+07
2761	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	239	75	0	2026-10-22 00:13:01.879+07	2026-10-22 00:13:01.88318+07
2762	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	244	75	0	2026-10-22 00:13:01.879+07	2026-10-22 00:13:01.885416+07
2763	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	237	75	0	2026-10-22 00:13:05.374+07	2026-10-22 00:13:05.378959+07
2764	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	241	75	0	2026-10-22 00:13:05.374+07	2026-10-22 00:13:05.38072+07
2765	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	41	0	6.67	2026-10-22 00:13:06.325+07	2026-10-22 00:13:08.87373+07
2766	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	236	75	0	2026-10-22 00:13:08.87+07	2026-10-22 00:13:08.8754+07
2767	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	234	75	0	2026-10-22 00:13:12.37+07	2026-10-22 00:13:12.373568+07
2768	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	238	75	0	2026-10-22 00:13:12.37+07	2026-10-22 00:13:12.375265+07
2769	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	47	0	27.33	2026-10-22 00:13:13.353+07	2026-10-22 00:13:15.874083+07
2770	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	242	75	0	2026-10-22 00:13:15.87+07	2026-10-22 00:13:15.875955+07
2771	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	233	75	0	2026-10-22 00:13:19.374+07	2026-10-22 00:13:19.379825+07
2772	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	245	75	0	2026-10-22 00:13:19.374+07	2026-10-22 00:13:19.381871+07
2773	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	233	75	0	2026-10-22 00:13:22.882+07	2026-10-22 00:13:22.89098+07
2774	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	244	75	0	2026-10-22 00:13:22.882+07	2026-10-22 00:13:22.895441+07
2779	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	240	75	0	2026-10-22 00:13:33.375+07	2026-10-22 00:13:33.378553+07
2780	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	234	75	0	2026-10-22 00:13:33.375+07	2026-10-22 00:13:33.380097+07
2781	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	235	75	0	2026-10-22 00:13:36.874+07	2026-10-22 00:13:36.877747+07
2782	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	240	75	0	2026-10-22 00:13:36.874+07	2026-10-22 00:13:36.879247+07
2783	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	184	75	0	2026-10-22 00:13:40.371+07	2026-10-22 00:13:40.374558+07
2784	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	238	75	0	2026-10-22 00:13:40.371+07	2026-10-22 00:13:40.375973+07
2940	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	245	75	0	2026-10-22 00:29:58.88+07	2026-10-22 00:29:58.889033+07
2941	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	233	75	0	2026-10-22 00:29:58.88+07	2026-10-22 00:29:58.892637+07
2944	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	235	75	0	2026-10-22 00:30:05.884+07	2026-10-22 00:30:05.894105+07
2945	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	245	75	0	2026-10-22 00:30:05.884+07	2026-10-22 00:30:05.899316+07
2948	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	49	0	13.67	2026-10-22 00:30:10.354+07	2026-10-22 00:30:12.877654+07
2949	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	234	75	0	2026-10-22 00:30:12.873+07	2026-10-22 00:30:12.879234+07
2952	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	235	75	0	2026-10-22 00:30:17.389+07	2026-10-22 00:30:17.397523+07
2953	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	244	75	0	2026-10-22 00:30:17.387+07	2026-10-22 00:30:17.400738+07
2954	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	243	75	0	2026-10-22 00:30:20.879+07	2026-10-22 00:30:20.8853+07
2955	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	234	75	0	2026-10-22 00:30:20.879+07	2026-10-22 00:30:20.887923+07
2958	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	239	75	0	2026-10-22 00:30:27.88+07	2026-10-22 00:30:27.886078+07
2959	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	230	75	0	2026-10-22 00:30:27.88+07	2026-10-22 00:30:27.888553+07
2962	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	243	75	0	2026-10-22 00:30:34.88+07	2026-10-22 00:30:34.885828+07
2963	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	232	75	0	2026-10-22 00:30:34.88+07	2026-10-22 00:30:34.887817+07
2966	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	230	75	0	2026-10-22 00:30:41.883+07	2026-10-22 00:30:41.893539+07
2967	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	243	75	0	2026-10-22 00:30:41.883+07	2026-10-22 00:30:41.898911+07
2974	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	64	0	20.33	2026-10-22 00:30:54.429+07	2026-10-22 00:30:54.436967+07
2975	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	51	0	18.67	2026-10-22 00:30:54.433+07	2026-10-22 00:30:54.438272+07
2978	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	48	0	9	2026-10-22 00:30:58.861+07	2026-10-22 00:31:01.379686+07
2979	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	237	75	0	2026-10-22 00:31:01.375+07	2026-10-22 00:31:01.381181+07
2980	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	244	75	0	2026-10-22 00:31:04.878+07	2026-10-22 00:31:04.886361+07
2981	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	233	75	0	2026-10-22 00:31:04.878+07	2026-10-22 00:31:04.889559+07
3101	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	236	75	0	2026-10-22 00:47:29.372+07	2026-10-22 00:47:29.381195+07
3198	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	216	75	0	2026-10-22 00:50:59.873+07	2026-10-22 00:50:59.87985+07
3199	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	222	75	0	2026-10-22 00:50:59.873+07	2026-10-22 00:50:59.881868+07
3206	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	250	75	0	2026-10-22 00:51:14.388+07	2026-10-22 00:51:14.400788+07
3207	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	242	75	0	2026-10-22 00:51:14.388+07	2026-10-22 00:51:14.404832+07
3210	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	50	0	16.67	2026-10-22 00:51:19.38+07	2026-10-22 00:51:19.384837+07
3211	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	49	0	17.33	2026-10-22 00:51:19.375+07	2026-10-22 00:51:19.386594+07
3212	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	68	0	35.33	2026-10-22 00:51:20.441+07	2026-10-22 00:51:22.883891+07
3213	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	243	75	0	2026-10-22 00:51:22.877+07	2026-10-22 00:51:22.887443+07
3216	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	212	75	0	2026-10-22 00:51:29.879+07	2026-10-22 00:51:29.883171+07
3217	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	200	75	0	2026-10-22 00:51:29.879+07	2026-10-22 00:51:29.88468+07
3224	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	238	75	0	2026-10-22 01:07:17.379+07	2026-10-22 01:07:17.38519+07
3262	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	236	75	0	2026-10-22 01:15:53.88+07	2026-10-22 01:15:53.895076+07
3263	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	243	75	0	2026-10-22 01:15:53.879+07	2026-10-22 01:15:53.900447+07
3313	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	43	0	7	2026-10-22 01:17:18.829+07	2026-10-22 01:17:18.859575+07
3314	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	232	75	0	2026-10-22 01:17:22.374+07	2026-10-22 01:17:22.379137+07
3315	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	242	75	0	2026-10-22 01:17:22.374+07	2026-10-22 01:17:22.38063+07
3318	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	240	75	0	2026-10-22 01:17:29.376+07	2026-10-22 01:17:29.380723+07
3319	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	236	75	0	2026-10-22 01:17:29.376+07	2026-10-22 01:17:29.382396+07
3322	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	225	75	0	2026-10-22 01:17:36.374+07	2026-10-22 01:17:36.379273+07
3323	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	222	75	0	2026-10-22 01:17:36.374+07	2026-10-22 01:17:36.380944+07
3326	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	233	75	0	2026-10-22 01:17:43.372+07	2026-10-22 01:17:44.911042+07
3327	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	237	75	0	2026-10-22 01:17:43.372+07	2026-10-22 01:17:44.912819+07
3328	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	221	75	0	2026-10-22 01:17:46.869+07	2026-10-22 01:17:48.408315+07
3329	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	224	75	0	2026-10-22 01:17:46.869+07	2026-10-22 01:17:48.410639+07
3330	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	254	75	0	2026-10-22 01:17:50.377+07	2026-10-22 01:17:52.413177+07
3331	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 01:17:52.408+07	2026-10-22 01:17:52.414709+07
3332	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	230	75	0	2026-10-22 01:17:55.899+07	2026-10-22 01:17:55.903325+07
3333	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	241	75	0	2026-10-22 01:17:55.899+07	2026-10-22 01:17:55.904854+07
2775	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	243	75	0	2026-10-22 00:13:26.37+07	2026-10-22 00:13:26.373721+07
2776	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	234	75	0	2026-10-22 00:13:26.37+07	2026-10-22 00:13:26.375436+07
2777	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	244	75	0	2026-10-22 00:13:29.879+07	2026-10-22 00:13:29.884685+07
2778	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	233	75	0	2026-10-22 00:13:29.879+07	2026-10-22 00:13:29.887734+07
2785	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	239	75	0	2026-10-22 00:13:43.878+07	2026-10-22 00:13:43.883417+07
2786	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	231	75	0	2026-10-22 00:13:43.878+07	2026-10-22 00:13:43.885978+07
2787	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	227	75	0	2026-10-22 00:13:47.375+07	2026-10-22 00:13:47.38191+07
2788	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	239	75	0	2026-10-22 00:13:47.375+07	2026-10-22 00:13:47.384338+07
2789	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	245	75	0	2026-10-22 00:13:50.874+07	2026-10-22 00:13:50.878192+07
2790	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	235	75	0	2026-10-22 00:13:50.874+07	2026-10-22 00:13:50.879684+07
2791	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	228	75	0	2026-10-22 00:13:54.375+07	2026-10-22 00:13:54.378776+07
2792	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	216	75	0	2026-10-22 00:13:54.375+07	2026-10-22 00:13:54.380192+07
2942	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	228	75	0	2026-10-22 00:30:02.369+07	2026-10-22 00:30:02.375389+07
2943	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	239	75	0	2026-10-22 00:30:02.369+07	2026-10-22 00:30:02.3781+07
2946	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	238	75	0	2026-10-22 00:30:09.375+07	2026-10-22 00:30:09.380091+07
2947	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	233	75	0	2026-10-22 00:30:09.375+07	2026-10-22 00:30:09.382436+07
2950	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	58	0	14.67	2026-10-22 00:30:13.907+07	2026-10-22 00:30:13.916028+07
2951	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	56	0	12.33	2026-10-22 00:30:13.912+07	2026-10-22 00:30:13.917616+07
2956	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	234	75	0	2026-10-22 00:30:24.373+07	2026-10-22 00:30:24.37821+07
2957	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	245	75	0	2026-10-22 00:30:24.373+07	2026-10-22 00:30:24.380045+07
2960	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	247	75	0	2026-10-22 00:30:31.378+07	2026-10-22 00:30:31.384681+07
2961	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	251	75	0	2026-10-22 00:30:31.378+07	2026-10-22 00:30:31.386922+07
2964	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	236	75	0	2026-10-22 00:30:38.369+07	2026-10-22 00:30:38.373273+07
2965	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	240	75	0	2026-10-22 00:30:38.369+07	2026-10-22 00:30:38.375292+07
2968	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	243	75	0	2026-10-22 00:30:45.368+07	2026-10-22 00:30:45.875529+07
2969	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 00:30:45.869+07	2026-10-22 00:30:45.879234+07
2970	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	243	75	0	2026-10-22 00:30:49.369+07	2026-10-22 00:30:49.373648+07
2971	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	233	75	0	2026-10-22 00:30:49.369+07	2026-10-22 00:30:49.376765+07
2972	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 00:30:53.377+07	2026-10-22 00:30:53.382082+07
2973	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	50	0	7.33	2026-10-22 00:30:50.351+07	2026-10-22 00:30:53.383997+07
2976	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	43	0	22.33	2026-10-22 00:30:55.401+07	2026-10-22 00:30:57.877392+07
2977	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	238	75	0	2026-10-22 00:30:57.871+07	2026-10-22 00:30:57.879541+07
3102	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	246	75	0	2026-10-22 00:48:10.886+07	2026-10-22 00:48:10.901055+07
3103	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	235	75	0	2026-10-22 00:48:10.885+07	2026-10-22 00:48:10.905612+07
3104	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	743	75	0	2026-10-22 00:48:11.878+07	2026-10-22 00:48:11.889799+07
3105	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	738	75	0	2026-10-22 00:48:11.878+07	2026-10-22 00:48:11.894601+07
3108	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	725	75	0	2026-10-22 00:48:19.867+07	2026-10-22 00:48:19.872433+07
3109	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	713	75	0	2026-10-22 00:48:19.867+07	2026-10-22 00:48:19.874068+07
3112	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	737	75	0	2026-10-22 00:48:27.386+07	2026-10-22 00:48:27.396877+07
3113	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	727	75	0	2026-10-22 00:48:27.386+07	2026-10-22 00:48:27.403938+07
3116	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	746	75	0	2026-10-22 00:48:35.382+07	2026-10-22 00:48:35.394104+07
3117	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	736	75	0	2026-10-22 00:48:35.382+07	2026-10-22 00:48:35.397473+07
3120	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	738	75	0	2026-10-22 00:48:43.385+07	2026-10-22 00:48:43.395148+07
3121	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	745	75	0	2026-10-22 00:48:43.385+07	2026-10-22 00:48:43.400985+07
3126	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	725	75	0	2026-10-22 00:48:55.369+07	2026-10-22 00:48:55.373726+07
3127	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	718	75	0	2026-10-22 00:48:55.369+07	2026-10-22 00:48:55.375427+07
3132	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	242	75	0	2026-10-22 00:49:06.869+07	2026-10-22 00:49:06.873652+07
3133	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	231	75	0	2026-10-22 00:49:06.869+07	2026-10-22 00:49:06.875227+07
3138	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	244	75	0	2026-10-22 00:49:17.371+07	2026-10-22 00:49:17.376191+07
3139	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	249	75	0	2026-10-22 00:49:17.372+07	2026-10-22 00:49:17.37884+07
3146	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	220	75	0	2026-10-22 00:49:31.377+07	2026-10-22 00:49:31.383002+07
3147	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	213	75	0	2026-10-22 00:49:31.377+07	2026-10-22 00:49:31.386383+07
3218	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-22 00:54:37.867+07	2026-10-22 00:54:37.874094+07
3225	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	offline	\N	100	0	2026-10-22 01:10:21.881+07	2026-10-22 01:10:21.892474+07
3226	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	242	75	0	2026-10-22 01:10:27.376+07	2026-10-22 01:10:27.383844+07
3285	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	228	75	0	2026-10-22 01:16:32.377+07	2026-10-22 01:16:32.382979+07
3288	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	240	75	0	2026-10-22 01:16:39.38+07	2026-10-22 01:16:39.385162+07
3289	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	229	75	0	2026-10-22 01:16:39.38+07	2026-10-22 01:16:39.38695+07
3366	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	241	75	0	2026-10-22 01:24:08.417+07	2026-10-22 01:24:08.425766+07
3369	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	231	75	0	2026-10-22 01:24:15.412+07	2026-10-22 01:24:15.4237+07
3370	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	241	75	0	2026-10-22 01:24:15.412+07	2026-10-22 01:24:15.428639+07
4748	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	227	75	0	2026-10-22 03:23:08.901+07	2026-10-22 03:23:08.909067+07
4749	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	229	75	0	2026-10-22 03:23:08.902+07	2026-10-22 03:23:08.912242+07
4750	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	236	75	0	2026-10-22 03:23:08.902+07	2026-10-22 03:23:08.9147+07
4751	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	219	75	0	2026-10-22 03:23:08.901+07	2026-10-22 03:23:08.916565+07
4752	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	238	75	0	2026-10-22 03:23:08.901+07	2026-10-22 03:23:08.91828+07
4972	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	227	75	0	2026-10-22 03:40:08.399+07	2026-10-22 03:40:08.408448+07
4973	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	219	75	0	2026-10-22 03:40:08.401+07	2026-10-22 03:40:08.410457+07
4974	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	234	75	0	2026-10-22 03:40:08.401+07	2026-10-22 03:40:08.412184+07
4975	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	247	75	0	2026-10-22 03:40:08.399+07	2026-10-22 03:40:08.41396+07
4976	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	241	75	0	2026-10-22 03:40:08.401+07	2026-10-22 03:40:08.415641+07
4977	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	223	75	0	2026-10-22 03:40:11.918+07	2026-10-22 03:40:11.925923+07
4978	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	208	75	0	2026-10-22 03:40:11.918+07	2026-10-22 03:40:11.929339+07
4979	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	242	75	0	2026-10-22 03:40:11.918+07	2026-10-22 03:40:11.932517+07
4980	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	236	75	0	2026-10-22 03:40:11.919+07	2026-10-22 03:40:11.935694+07
4981	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	200	75	0	2026-10-22 03:40:11.918+07	2026-10-22 03:40:11.939692+07
4997	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	216	75	0	2026-10-22 03:40:25.913+07	2026-10-22 03:40:25.91975+07
4998	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	225	75	0	2026-10-22 03:40:25.911+07	2026-10-22 03:40:25.923034+07
4999	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	208	75	0	2026-10-22 03:40:25.911+07	2026-10-22 03:40:25.925774+07
5000	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	213	75	0	2026-10-22 03:40:25.911+07	2026-10-22 03:40:25.927928+07
5001	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	222	75	0	2026-10-22 03:40:25.912+07	2026-10-22 03:40:25.929868+07
5012	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	215	75	0	2026-10-22 03:40:36.412+07	2026-10-22 03:40:36.416196+07
5013	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	224	75	0	2026-10-22 03:40:36.412+07	2026-10-22 03:40:36.417834+07
5014	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	211	75	0	2026-10-22 03:40:36.412+07	2026-10-22 03:40:36.420916+07
5015	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	225	75	0	2026-10-22 03:40:36.412+07	2026-10-22 03:40:36.423833+07
5016	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	217	75	0	2026-10-22 03:40:36.412+07	2026-10-22 03:40:36.426574+07
5022	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	130	0	85.33	2026-10-22 03:40:41.255+07	2026-10-22 03:40:43.408202+07
5023	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	241	75	0	2026-10-22 03:40:43.403+07	2026-10-22 03:40:43.410107+07
5024	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	129	0	80.33	2026-10-22 03:40:41.263+07	2026-10-22 03:40:43.412095+07
5025	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	126	0	79.33	2026-10-22 03:40:41.257+07	2026-10-22 03:40:43.414288+07
5026	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	236	75	0	2026-10-22 03:40:43.403+07	2026-10-22 03:40:43.416949+07
5027	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	212	75	0	2026-10-22 03:40:46.915+07	2026-10-22 03:40:46.922549+07
5028	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	225	75	0	2026-10-22 03:40:46.915+07	2026-10-22 03:40:46.925626+07
5029	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	216	75	0	2026-10-22 03:40:46.915+07	2026-10-22 03:40:46.928193+07
5030	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	222	75	0	2026-10-22 03:40:46.915+07	2026-10-22 03:40:46.930394+07
5031	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	207	75	0	2026-10-22 03:40:46.915+07	2026-10-22 03:40:46.932644+07
5067	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	216	75	0	2026-10-22 03:41:47.917+07	2026-10-22 03:41:47.929775+07
5068	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	228	75	0	2026-10-22 03:41:47.917+07	2026-10-22 03:41:47.937608+07
5069	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	203	75	0	2026-10-22 03:41:47.916+07	2026-10-22 03:41:47.943181+07
5070	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	250	75	0	2026-10-22 03:41:47.916+07	2026-10-22 03:41:47.948222+07
5071	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	239	75	0	2026-10-22 03:41:47.919+07	2026-10-22 03:41:47.954545+07
5072	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	727	75	0	2026-10-22 03:41:51.915+07	2026-10-22 03:41:51.92205+07
5073	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	693	75	0	2026-10-22 03:41:51.915+07	2026-10-22 03:41:51.92447+07
5074	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	739	75	0	2026-10-22 03:41:51.915+07	2026-10-22 03:41:51.926586+07
5075	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	713	75	0	2026-10-22 03:41:51.915+07	2026-10-22 03:41:51.928427+07
5076	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	702	75	0	2026-10-22 03:41:51.915+07	2026-10-22 03:41:51.930262+07
5077	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	739	75	0	2026-10-22 03:41:55.912+07	2026-10-22 03:41:55.916706+07
5078	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	729	75	0	2026-10-22 03:41:55.912+07	2026-10-22 03:41:55.919715+07
5079	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	735	75	0	2026-10-22 03:41:55.912+07	2026-10-22 03:41:55.922147+07
5080	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	744	75	0	2026-10-22 03:41:55.912+07	2026-10-22 03:41:55.924346+07
5081	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	74	0	12.33	2026-10-22 03:41:53.016+07	2026-10-22 03:41:55.926374+07
5082	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	732	75	0	2026-10-22 03:41:59.909+07	2026-10-22 03:41:59.915039+07
5083	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	696	75	0	2026-10-22 03:41:59.909+07	2026-10-22 03:41:59.918752+07
5084	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	709	75	0	2026-10-22 03:41:59.908+07	2026-10-22 03:41:59.92257+07
5085	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	81	0	11.33	2026-10-22 03:41:57.041+07	2026-10-22 03:41:59.926158+07
5086	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	721	75	0	2026-10-22 03:41:59.909+07	2026-10-22 03:41:59.929499+07
3367	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	242	75	0	2026-10-22 01:24:11.919+07	2026-10-22 01:24:11.928448+07
3368	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	229	75	0	2026-10-22 01:24:11.918+07	2026-10-22 01:24:11.933767+07
3371	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	237	75	0	2026-10-22 01:24:18.908+07	2026-10-22 01:24:18.916092+07
3372	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	246	75	0	2026-10-22 01:24:18.908+07	2026-10-22 01:24:18.918439+07
3373	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	245	75	0	2026-10-22 01:24:22.408+07	2026-10-22 01:24:22.412807+07
3374	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	240	75	0	2026-10-22 01:24:22.408+07	2026-10-22 01:24:22.415409+07
3375	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	243	75	0	2026-10-22 01:24:25.911+07	2026-10-22 01:24:25.919685+07
3376	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	233	75	0	2026-10-22 01:24:25.911+07	2026-10-22 01:24:25.924343+07
3377	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	259	75	0	2026-10-22 01:24:29.405+07	2026-10-22 01:24:29.414345+07
3378	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	248	75	0	2026-10-22 01:24:29.405+07	2026-10-22 01:24:29.419618+07
3379	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	250	75	0	2026-10-22 01:24:32.915+07	2026-10-22 01:24:32.91914+07
3380	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	238	75	0	2026-10-22 01:24:32.915+07	2026-10-22 01:24:32.920783+07
3381	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	231	75	0	2026-10-22 01:24:36.41+07	2026-10-22 01:24:36.418558+07
3382	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	241	75	0	2026-10-22 01:24:36.41+07	2026-10-22 01:24:36.422794+07
3383	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	231	75	0	2026-10-22 01:24:39.945+07	2026-10-22 01:24:39.952664+07
3384	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	243	75	0	2026-10-22 01:24:39.945+07	2026-10-22 01:24:39.956614+07
3385	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	231	75	0	2026-10-22 01:24:43.415+07	2026-10-22 01:24:43.423036+07
3386	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	241	75	0	2026-10-22 01:24:43.415+07	2026-10-22 01:24:43.426306+07
3387	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	233	75	0	2026-10-22 01:24:46.908+07	2026-10-22 01:24:46.915144+07
3388	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	242	75	0	2026-10-22 01:24:46.908+07	2026-10-22 01:24:46.918893+07
3389	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	231	75	0	2026-10-22 01:24:50.406+07	2026-10-22 01:24:50.415255+07
3390	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	240	75	0	2026-10-22 01:24:50.406+07	2026-10-22 01:24:50.418699+07
3391	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	243	75	0	2026-10-22 01:24:53.91+07	2026-10-22 01:24:53.923204+07
3392	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	234	75	0	2026-10-22 01:24:53.911+07	2026-10-22 01:24:53.928352+07
3393	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	231	75	0	2026-10-22 01:24:57.415+07	2026-10-22 01:24:57.420794+07
3394	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	241	75	0	2026-10-22 01:24:57.415+07	2026-10-22 01:24:57.423594+07
3395	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	239	75	0	2026-10-22 01:25:00.916+07	2026-10-22 01:25:00.924725+07
3396	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	245	75	0	2026-10-22 01:25:00.916+07	2026-10-22 01:25:00.929144+07
3397	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	262	75	0	2026-10-22 01:25:04.405+07	2026-10-22 01:25:04.415203+07
3398	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	252	75	0	2026-10-22 01:25:04.406+07	2026-10-22 01:25:04.421139+07
3399	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	241	75	0	2026-10-22 01:25:07.916+07	2026-10-22 01:25:07.926009+07
3400	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	236	75	0	2026-10-22 01:25:07.915+07	2026-10-22 01:25:07.932326+07
3401	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	244	75	0	2026-10-22 01:25:11.404+07	2026-10-22 01:25:11.411633+07
3402	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	233	75	0	2026-10-22 01:25:11.404+07	2026-10-22 01:25:11.4163+07
3403	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	236	75	0	2026-10-22 01:25:14.91+07	2026-10-22 01:25:14.915306+07
3404	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	241	75	0	2026-10-22 01:25:14.91+07	2026-10-22 01:25:14.918023+07
3405	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	215	75	0	2026-10-22 01:25:18.409+07	2026-10-22 01:25:18.418955+07
3406	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	227	75	0	2026-10-22 01:25:18.409+07	2026-10-22 01:25:18.423499+07
3407	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	233	75	0	2026-10-22 01:25:21.916+07	2026-10-22 01:25:21.925861+07
3408	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	244	75	0	2026-10-22 01:25:21.917+07	2026-10-22 01:25:21.931871+07
3409	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	242	75	0	2026-10-22 01:25:25.406+07	2026-10-22 01:25:25.412371+07
3410	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	253	75	0	2026-10-22 01:25:25.406+07	2026-10-22 01:25:25.416264+07
3411	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	241	75	0	2026-10-22 01:25:28.91+07	2026-10-22 01:25:28.918607+07
3412	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	236	75	0	2026-10-22 01:25:28.91+07	2026-10-22 01:25:28.92129+07
3413	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	231	75	0	2026-10-22 01:25:32.42+07	2026-10-22 01:25:32.427712+07
3414	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	242	75	0	2026-10-22 01:25:32.419+07	2026-10-22 01:25:32.432514+07
3415	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	232	75	0	2026-10-22 01:25:35.918+07	2026-10-22 01:25:35.927021+07
3416	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	242	75	0	2026-10-22 01:25:35.918+07	2026-10-22 01:25:35.931997+07
3417	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	240	75	0	2026-10-22 01:25:39.407+07	2026-10-22 01:25:39.422056+07
3418	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	234	75	0	2026-10-22 01:25:39.407+07	2026-10-22 01:25:39.424978+07
3419	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	230	75	0	2026-10-22 01:25:42.911+07	2026-10-22 01:25:42.915859+07
3420	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	236	75	0	2026-10-22 01:25:42.911+07	2026-10-22 01:25:42.91745+07
3421	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	231	75	0	2026-10-22 01:25:46.404+07	2026-10-22 01:25:46.409981+07
3422	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	242	75	0	2026-10-22 01:25:46.404+07	2026-10-22 01:25:46.411855+07
3423	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	243	75	0	2026-10-22 01:25:49.916+07	2026-10-22 01:25:49.924566+07
3424	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	235	75	0	2026-10-22 01:25:49.917+07	2026-10-22 01:25:49.929197+07
3425	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	219	75	0	2026-10-22 01:25:53.406+07	2026-10-22 01:25:53.410632+07
3426	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	223	75	0	2026-10-22 01:25:53.406+07	2026-10-22 01:25:53.41241+07
3427	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	47	0	8.33	2026-10-22 01:25:54.39+07	2026-10-22 01:25:56.914167+07
3428	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	241	75	0	2026-10-22 01:25:56.91+07	2026-10-22 01:25:56.916004+07
3431	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	235	75	0	2026-10-22 01:26:00.906+07	2026-10-22 01:26:00.911556+07
3432	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	239	75	0	2026-10-22 01:26:00.907+07	2026-10-22 01:26:00.913586+07
3439	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	239	75	0	2026-10-22 01:26:14.904+07	2026-10-22 01:26:14.908283+07
3440	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	229	75	0	2026-10-22 01:26:14.904+07	2026-10-22 01:26:14.909955+07
3449	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	239	75	0	2026-10-22 01:26:32.9+07	2026-10-22 01:26:32.904932+07
3450	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	242	75	0	2026-10-22 01:26:32.9+07	2026-10-22 01:26:32.907657+07
3451	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 01:26:36.909+07	2026-10-22 01:26:36.91377+07
3452	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	137	0	18.67	2026-10-22 01:26:34.241+07	2026-10-22 01:26:36.915359+07
3455	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	41	0	6.67	2026-10-22 01:26:38.801+07	2026-10-22 01:26:41.422018+07
3456	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	239	75	0	2026-10-22 01:26:41.412+07	2026-10-22 01:26:41.427459+07
4753	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	241	75	0	2026-10-22 03:23:52.418+07	2026-10-22 03:23:52.434522+07
4754	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	266	75	0	2026-10-22 03:23:52.419+07	2026-10-22 03:23:52.436796+07
4755	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	264	75	0	2026-10-22 03:23:52.426+07	2026-10-22 03:23:52.438531+07
4756	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	234	75	0	2026-10-22 03:23:52.426+07	2026-10-22 03:23:52.440584+07
4757	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	212	75	0	2026-10-22 03:23:52.418+07	2026-10-22 03:23:52.442325+07
4758	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	725	75	0	2026-10-22 03:23:54.414+07	2026-10-22 03:23:54.421152+07
4759	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	693	75	0	2026-10-22 03:23:54.414+07	2026-10-22 03:23:54.423944+07
4760	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	698	75	0	2026-10-22 03:23:54.414+07	2026-10-22 03:23:54.426638+07
4761	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	729	75	0	2026-10-22 03:23:54.413+07	2026-10-22 03:23:54.429478+07
4762	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	702	75	0	2026-10-22 03:23:54.413+07	2026-10-22 03:23:54.431839+07
4763	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	731	75	0	2026-10-22 03:23:58.411+07	2026-10-22 03:23:58.416631+07
4764	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	736	75	0	2026-10-22 03:23:58.411+07	2026-10-22 03:23:58.418246+07
4765	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	747	75	0	2026-10-22 03:23:58.411+07	2026-10-22 03:23:58.419801+07
4766	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	744	75	0	2026-10-22 03:23:58.411+07	2026-10-22 03:23:58.421322+07
4767	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	740	75	0	2026-10-22 03:23:58.411+07	2026-10-22 03:23:58.423409+07
4768	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	719	75	0	2026-10-22 03:24:02.403+07	2026-10-22 03:24:02.410048+07
4769	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	712	75	0	2026-10-22 03:24:02.403+07	2026-10-22 03:24:02.413006+07
4770	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	726	75	0	2026-10-22 03:24:02.403+07	2026-10-22 03:24:02.41561+07
4771	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	705	75	0	2026-10-22 03:24:02.403+07	2026-10-22 03:24:02.417726+07
4772	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	47	0	12.67	2026-10-22 03:23:59.406+07	2026-10-22 03:24:02.419648+07
4773	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	717	75	0	2026-10-22 03:24:06.403+07	2026-10-22 03:24:06.408456+07
4774	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	727	75	0	2026-10-22 03:24:06.404+07	2026-10-22 03:24:06.410932+07
4775	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	713	75	0	2026-10-22 03:24:06.403+07	2026-10-22 03:24:06.413614+07
4776	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	66	0	11.67	2026-10-22 03:24:03.493+07	2026-10-22 03:24:06.415516+07
4777	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	721	75	0	2026-10-22 03:24:06.403+07	2026-10-22 03:24:06.417459+07
4778	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	724	75	0	2026-10-22 03:24:10.418+07	2026-10-22 03:24:10.423326+07
4779	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	718	75	0	2026-10-22 03:24:10.415+07	2026-10-22 03:24:10.425497+07
4780	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	737	75	0	2026-10-22 03:24:10.415+07	2026-10-22 03:24:10.427954+07
4781	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	730	75	0	2026-10-22 03:24:10.418+07	2026-10-22 03:24:10.430332+07
4782	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	744	75	0	2026-10-22 03:24:10.415+07	2026-10-22 03:24:10.432114+07
4783	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	720	75	0	2026-10-22 03:24:14.401+07	2026-10-22 03:24:14.407593+07
4784	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	731	75	0	2026-10-22 03:24:14.402+07	2026-10-22 03:24:14.41084+07
4785	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	735	75	0	2026-10-22 03:24:14.402+07	2026-10-22 03:24:14.413179+07
4786	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	725	75	0	2026-10-22 03:24:14.401+07	2026-10-22 03:24:14.415023+07
4787	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	738	75	0	2026-10-22 03:24:14.401+07	2026-10-22 03:24:14.416911+07
4838	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	731	75	0	2026-10-22 03:24:55.413+07	2026-10-22 03:24:55.418492+07
4839	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	745	75	0	2026-10-22 03:24:55.413+07	2026-10-22 03:24:55.420384+07
4840	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	737	75	0	2026-10-22 03:24:55.411+07	2026-10-22 03:24:55.422089+07
4841	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	738	75	0	2026-10-22 03:24:55.411+07	2026-10-22 03:24:55.423871+07
4842	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	728	75	0	2026-10-22 03:24:55.413+07	2026-10-22 03:24:55.426169+07
4843	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	734	75	0	2026-10-22 03:24:59.412+07	2026-10-22 03:24:59.424328+07
4844	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	750	75	0	2026-10-22 03:24:59.412+07	2026-10-22 03:24:59.430311+07
4845	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	739	75	0	2026-10-22 03:24:59.412+07	2026-10-22 03:24:59.43501+07
4846	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	743	75	0	2026-10-22 03:24:59.41+07	2026-10-22 03:24:59.439465+07
4847	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	746	75	0	2026-10-22 03:24:59.415+07	2026-10-22 03:24:59.445213+07
4848	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	240	75	0	2026-10-22 03:25:02.927+07	2026-10-22 03:25:02.93837+07
3429	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	37	0	4	2026-10-22 01:25:57.836+07	2026-10-22 01:25:57.843005+07
3430	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	35	0	3.67	2026-10-22 01:25:57.839+07	2026-10-22 01:25:57.84459+07
3433	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	231	75	0	2026-10-22 01:26:04.404+07	2026-10-22 01:26:04.411862+07
3434	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	242	75	0	2026-10-22 01:26:04.404+07	2026-10-22 01:26:04.414139+07
3435	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	237	75	0	2026-10-22 01:26:07.911+07	2026-10-22 01:26:07.915344+07
3436	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	243	75	0	2026-10-22 01:26:07.911+07	2026-10-22 01:26:07.916922+07
3437	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	237	75	0	2026-10-22 01:26:11.418+07	2026-10-22 01:26:11.427546+07
3438	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	243	75	0	2026-10-22 01:26:11.418+07	2026-10-22 01:26:11.431313+07
3443	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	236	75	0	2026-10-22 01:26:21.913+07	2026-10-22 01:26:21.917055+07
3444	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	224	75	0	2026-10-22 01:26:21.913+07	2026-10-22 01:26:21.91872+07
3445	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	239	75	0	2026-10-22 01:26:25.405+07	2026-10-22 01:26:25.409625+07
3446	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	245	75	0	2026-10-22 01:26:25.405+07	2026-10-22 01:26:25.411235+07
4788	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	721	75	0	2026-10-22 03:24:18.403+07	2026-10-22 03:24:18.411483+07
4789	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	734	75	0	2026-10-22 03:24:18.403+07	2026-10-22 03:24:18.415216+07
4790	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	738	75	0	2026-10-22 03:24:18.403+07	2026-10-22 03:24:18.417364+07
4791	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	730	75	0	2026-10-22 03:24:18.403+07	2026-10-22 03:24:18.419512+07
4792	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	726	75	0	2026-10-22 03:24:18.403+07	2026-10-22 03:24:18.42186+07
4793	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	741	75	0	2026-10-22 03:24:22.419+07	2026-10-22 03:24:22.430352+07
4794	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	735	75	0	2026-10-22 03:24:22.419+07	2026-10-22 03:24:22.434795+07
4795	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	747	75	0	2026-10-22 03:24:22.419+07	2026-10-22 03:24:22.441102+07
4796	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	723	75	0	2026-10-22 03:24:22.419+07	2026-10-22 03:24:22.446192+07
4797	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	729	75	0	2026-10-22 03:24:22.419+07	2026-10-22 03:24:22.449756+07
4798	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	727	75	0	2026-10-22 03:24:26.411+07	2026-10-22 03:24:26.416342+07
4799	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	688	75	0	2026-10-22 03:24:26.41+07	2026-10-22 03:24:26.418733+07
4800	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	705	75	0	2026-10-22 03:24:26.405+07	2026-10-22 03:24:26.420527+07
4801	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	700	75	0	2026-10-22 03:24:26.405+07	2026-10-22 03:24:26.422847+07
4802	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	694	75	0	2026-10-22 03:24:26.41+07	2026-10-22 03:24:26.42447+07
4803	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	742	75	0	2026-10-22 03:24:27.411+07	2026-10-22 03:24:27.415638+07
4804	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	734	75	0	2026-10-22 03:24:27.411+07	2026-10-22 03:24:27.417301+07
4805	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	726	75	0	2026-10-22 03:24:27.411+07	2026-10-22 03:24:27.418851+07
4806	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	736	75	0	2026-10-22 03:24:27.409+07	2026-10-22 03:24:27.420416+07
4807	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	730	75	0	2026-10-22 03:24:27.411+07	2026-10-22 03:24:27.422218+07
4808	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	738	75	0	2026-10-22 03:24:31.416+07	2026-10-22 03:24:31.422143+07
4809	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	727	75	0	2026-10-22 03:24:31.416+07	2026-10-22 03:24:31.424673+07
4810	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	742	75	0	2026-10-22 03:24:31.415+07	2026-10-22 03:24:31.427084+07
4811	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	722	75	0	2026-10-22 03:24:31.416+07	2026-10-22 03:24:31.429268+07
4812	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	732	75	0	2026-10-22 03:24:31.416+07	2026-10-22 03:24:31.431373+07
4813	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	736	75	0	2026-10-22 03:24:35.409+07	2026-10-22 03:24:35.415254+07
4814	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	742	75	0	2026-10-22 03:24:35.409+07	2026-10-22 03:24:35.4174+07
4815	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	729	75	0	2026-10-22 03:24:35.409+07	2026-10-22 03:24:35.419412+07
4816	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	723	75	0	2026-10-22 03:24:35.409+07	2026-10-22 03:24:35.421374+07
4817	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	38	0	7.33	2026-10-22 03:24:32.384+07	2026-10-22 03:24:35.423235+07
4818	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	741	75	0	2026-10-22 03:24:39.413+07	2026-10-22 03:24:39.419402+07
4819	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	723	75	0	2026-10-22 03:24:39.413+07	2026-10-22 03:24:39.422407+07
4820	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	735	75	0	2026-10-22 03:24:39.413+07	2026-10-22 03:24:39.426128+07
4821	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	42	0	8.33	2026-10-22 03:24:36.383+07	2026-10-22 03:24:39.429502+07
4822	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	729	75	0	2026-10-22 03:24:39.413+07	2026-10-22 03:24:39.432192+07
4823	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	745	75	0	2026-10-22 03:24:43.417+07	2026-10-22 03:24:43.42317+07
4824	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	751	75	0	2026-10-22 03:24:43.417+07	2026-10-22 03:24:43.426191+07
4825	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	738	75	0	2026-10-22 03:24:43.417+07	2026-10-22 03:24:43.428587+07
4826	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	731	75	0	2026-10-22 03:24:43.417+07	2026-10-22 03:24:43.430826+07
4827	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	756	75	0	2026-10-22 03:24:43.417+07	2026-10-22 03:24:43.43271+07
4828	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	738	75	0	2026-10-22 03:24:47.402+07	2026-10-22 03:24:47.407206+07
4829	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	727	75	0	2026-10-22 03:24:47.402+07	2026-10-22 03:24:47.409286+07
4830	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	717	75	0	2026-10-22 03:24:47.403+07	2026-10-22 03:24:47.412047+07
4831	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	732	75	0	2026-10-22 03:24:47.403+07	2026-10-22 03:24:47.414337+07
4832	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	722	75	0	2026-10-22 03:24:47.402+07	2026-10-22 03:24:47.416503+07
4833	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	713	75	0	2026-10-22 03:24:51.401+07	2026-10-22 03:24:51.405595+07
3441	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	233	75	0	2026-10-22 01:26:18.406+07	2026-10-22 01:26:18.416061+07
3442	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	244	75	0	2026-10-22 01:26:18.406+07	2026-10-22 01:26:18.420542+07
3447	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	239	75	0	2026-10-22 01:26:28.899+07	2026-10-22 01:26:29.427814+07
3448	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 01:26:29.418+07	2026-10-22 01:26:29.433037+07
3453	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	39	0	11.67	2026-10-22 01:26:37.857+07	2026-10-22 01:26:37.861207+07
3454	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	35	0	1.33	2026-10-22 01:26:37.852+07	2026-10-22 01:26:37.863005+07
3457	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	39	0	17	2026-10-22 01:26:42.379+07	2026-10-22 01:26:44.921339+07
3458	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	240	75	0	2026-10-22 01:26:44.914+07	2026-10-22 01:26:44.9245+07
3459	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	225	75	0	2026-10-22 01:26:48.405+07	2026-10-22 01:26:48.411179+07
3460	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	222	75	0	2026-10-22 01:26:48.405+07	2026-10-22 01:26:48.413365+07
3461	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	234	75	0	2026-10-22 01:27:54.418+07	2026-10-22 01:27:54.433961+07
3462	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	222	75	0	2026-10-22 01:27:54.419+07	2026-10-22 01:27:54.458904+07
3463	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-22 01:27:55.419+07	2026-10-22 01:27:55.430512+07
3464	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	210	75	0	2026-10-22 01:27:55.419+07	2026-10-22 01:27:55.43637+07
3465	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	244	75	0	2026-10-22 01:27:58.917+07	2026-10-22 01:27:58.923657+07
3466	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	237	75	0	2026-10-22 01:27:58.917+07	2026-10-22 01:27:58.927039+07
3467	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	746	75	0	2026-10-22 01:28:02.912+07	2026-10-22 01:28:02.92908+07
3468	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	734	75	0	2026-10-22 01:28:02.912+07	2026-10-22 01:28:02.933059+07
3469	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	230	75	0	2026-10-22 01:28:06.413+07	2026-10-22 01:28:06.424284+07
3470	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	244	75	0	2026-10-22 01:28:06.413+07	2026-10-22 01:28:06.43055+07
3471	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	738	75	0	2026-10-22 01:28:10.41+07	2026-10-22 01:28:10.418687+07
3472	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	744	75	0	2026-10-22 01:28:10.41+07	2026-10-22 01:28:10.422351+07
3473	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	244	75	0	2026-10-22 01:28:13.904+07	2026-10-22 01:28:13.910471+07
3474	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	234	75	0	2026-10-22 01:28:13.903+07	2026-10-22 01:28:13.914725+07
3475	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	238	75	0	2026-10-22 01:28:17.407+07	2026-10-22 01:28:17.414978+07
3476	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	230	75	0	2026-10-22 01:28:17.407+07	2026-10-22 01:28:17.419401+07
3477	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	70	0	20.33	2026-10-22 01:28:18.481+07	2026-10-22 01:28:20.920085+07
3478	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	243	75	0	2026-10-22 01:28:20.907+07	2026-10-22 01:28:20.925684+07
3479	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	245	75	0	2026-10-22 01:28:24.411+07	2026-10-22 01:28:24.426475+07
3480	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	235	75	0	2026-10-22 01:28:24.41+07	2026-10-22 01:28:24.433512+07
3481	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	68	0	5	2026-10-22 01:28:25.493+07	2026-10-22 01:28:27.91908+07
3482	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	239	75	0	2026-10-22 01:28:27.908+07	2026-10-22 01:28:27.924434+07
3483	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	240	75	0	2026-10-22 01:28:31.399+07	2026-10-22 01:28:31.403752+07
3484	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	229	75	0	2026-10-22 01:28:31.399+07	2026-10-22 01:28:31.405676+07
3485	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	241	75	0	2026-10-22 01:28:34.906+07	2026-10-22 01:28:34.911382+07
3486	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	227	75	0	2026-10-22 01:28:34.906+07	2026-10-22 01:28:34.913877+07
3487	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	244	75	0	2026-10-22 01:28:38.416+07	2026-10-22 01:28:38.426723+07
3488	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	234	75	0	2026-10-22 01:28:38.416+07	2026-10-22 01:28:38.432977+07
3489	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	216	75	0	2026-10-22 01:28:41.915+07	2026-10-22 01:28:41.925408+07
3490	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	227	75	0	2026-10-22 01:28:41.915+07	2026-10-22 01:28:41.93147+07
3491	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	204	75	0	2026-10-22 01:28:45.419+07	2026-10-22 01:28:45.429435+07
3492	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	245	75	0	2026-10-22 01:28:45.419+07	2026-10-22 01:28:45.434982+07
3493	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	239	75	0	2026-10-22 01:28:48.918+07	2026-10-22 01:28:48.932642+07
3494	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	228	75	0	2026-10-22 01:28:48.92+07	2026-10-22 01:28:48.938728+07
3495	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	234	75	0	2026-10-22 01:28:52.411+07	2026-10-22 01:28:52.420821+07
3496	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	244	75	0	2026-10-22 01:28:52.411+07	2026-10-22 01:28:52.426746+07
3497	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	230	75	0	2026-10-22 01:28:55.914+07	2026-10-22 01:28:55.918378+07
3498	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	242	75	0	2026-10-22 01:28:55.914+07	2026-10-22 01:28:55.920537+07
3499	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	237	75	0	2026-10-22 01:28:59.405+07	2026-10-22 01:28:59.411553+07
3500	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	226	75	0	2026-10-22 01:28:59.405+07	2026-10-22 01:28:59.414766+07
3501	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	247	75	0	2026-10-22 01:29:02.913+07	2026-10-22 01:29:02.918498+07
3502	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	239	75	0	2026-10-22 01:29:02.913+07	2026-10-22 01:29:02.920597+07
3503	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	239	75	0	2026-10-22 01:29:06.414+07	2026-10-22 01:29:06.42374+07
3504	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	228	75	0	2026-10-22 01:29:06.414+07	2026-10-22 01:29:06.430536+07
3505	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	227	75	0	2026-10-22 01:29:09.914+07	2026-10-22 01:29:09.925419+07
3506	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	216	75	0	2026-10-22 01:29:09.914+07	2026-10-22 01:29:09.930754+07
3507	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	231	75	0	2026-10-22 01:29:13.402+07	2026-10-22 01:29:13.40899+07
3508	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	241	75	0	2026-10-22 01:29:13.402+07	2026-10-22 01:29:13.412504+07
3509	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	247	75	0	2026-10-22 01:29:16.911+07	2026-10-22 01:29:16.9216+07
3510	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	235	75	0	2026-10-22 01:29:16.911+07	2026-10-22 01:29:16.925067+07
3515	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	244	75	0	2026-10-22 01:29:27.402+07	2026-10-22 01:29:27.407602+07
3516	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	234	75	0	2026-10-22 01:29:27.402+07	2026-10-22 01:29:27.411758+07
3517	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	232	75	0	2026-10-22 01:29:30.903+07	2026-10-22 01:29:30.90739+07
3518	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	241	75	0	2026-10-22 01:29:30.903+07	2026-10-22 01:29:30.90923+07
3519	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	242	75	0	2026-10-22 01:29:34.407+07	2026-10-22 01:29:34.414933+07
3520	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	231	75	0	2026-10-22 01:29:34.407+07	2026-10-22 01:29:34.418811+07
3521	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	237	75	0	2026-10-22 01:29:37.908+07	2026-10-22 01:29:37.914621+07
3522	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	240	75	0	2026-10-22 01:29:37.908+07	2026-10-22 01:29:37.918327+07
3525	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	236	75	0	2026-10-22 01:29:44.912+07	2026-10-22 01:29:44.919834+07
3526	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	240	75	0	2026-10-22 01:29:44.912+07	2026-10-22 01:29:44.922658+07
3527	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	242	75	0	2026-10-22 01:29:48.415+07	2026-10-22 01:29:48.420207+07
3528	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	214	75	0	2026-10-22 01:29:48.415+07	2026-10-22 01:29:48.422755+07
3533	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	234	75	0	2026-10-22 01:29:58.916+07	2026-10-22 01:29:58.927958+07
3534	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	243	75	0	2026-10-22 01:29:58.917+07	2026-10-22 01:29:58.932234+07
3535	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	231	75	0	2026-10-22 01:30:02.42+07	2026-10-22 01:30:02.42686+07
3536	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	241	75	0	2026-10-22 01:30:02.42+07	2026-10-22 01:30:02.428684+07
3537	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	234	75	0	2026-10-22 01:30:05.911+07	2026-10-22 01:30:05.915596+07
3538	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	244	75	0	2026-10-22 01:30:05.911+07	2026-10-22 01:30:05.917227+07
3539	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	231	75	0	2026-10-22 01:30:09.413+07	2026-10-22 01:30:09.424377+07
3540	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	243	75	0	2026-10-22 01:30:09.413+07	2026-10-22 01:30:09.42859+07
4834	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	708	75	0	2026-10-22 03:24:51.401+07	2026-10-22 03:24:51.407329+07
4835	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	726	75	0	2026-10-22 03:24:51.401+07	2026-10-22 03:24:51.409361+07
4836	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	717	75	0	2026-10-22 03:24:51.401+07	2026-10-22 03:24:51.411497+07
4837	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	721	75	0	2026-10-22 03:24:51.401+07	2026-10-22 03:24:51.413739+07
5009	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	242	75	0	2026-10-22 03:40:32.902+07	2026-10-22 03:40:32.915655+07
5010	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	199	75	0	2026-10-22 03:40:32.906+07	2026-10-22 03:40:32.917745+07
5011	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	233	75	0	2026-10-22 03:40:32.906+07	2026-10-22 03:40:32.919999+07
5017	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	242	75	0	2026-10-22 03:40:39.931+07	2026-10-22 03:40:39.939146+07
5018	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	237	75	0	2026-10-22 03:40:39.929+07	2026-10-22 03:40:39.94303+07
5019	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	224	75	0	2026-10-22 03:40:39.932+07	2026-10-22 03:40:39.946637+07
5020	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	233	75	0	2026-10-22 03:40:39.914+07	2026-10-22 03:40:39.950552+07
5021	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	229	75	0	2026-10-22 03:40:39.931+07	2026-10-22 03:40:39.954838+07
5032	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	234	75	0	2026-10-22 03:40:50.406+07	2026-10-22 03:40:50.410688+07
5033	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	227	75	0	2026-10-22 03:40:50.406+07	2026-10-22 03:40:50.412421+07
5034	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	215	75	0	2026-10-22 03:40:50.406+07	2026-10-22 03:40:50.414069+07
5035	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	235	75	0	2026-10-22 03:40:50.406+07	2026-10-22 03:40:50.416342+07
5036	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	220	75	0	2026-10-22 03:40:50.406+07	2026-10-22 03:40:50.418598+07
5037	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	229	75	0	2026-10-22 03:40:53.91+07	2026-10-22 03:40:53.916153+07
5038	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	238	75	0	2026-10-22 03:40:53.907+07	2026-10-22 03:40:53.920132+07
5039	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	234	75	0	2026-10-22 03:40:53.91+07	2026-10-22 03:40:53.923572+07
5040	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	242	75	0	2026-10-22 03:40:53.91+07	2026-10-22 03:40:53.926583+07
5041	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	247	75	0	2026-10-22 03:40:53.907+07	2026-10-22 03:40:53.929198+07
5042	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	236	75	0	2026-10-22 03:40:57.414+07	2026-10-22 03:40:57.913065+07
5043	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 03:40:57.909+07	2026-10-22 03:40:57.914887+07
5044	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	225	75	0	2026-10-22 03:40:57.415+07	2026-10-22 03:40:57.916655+07
5045	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	211	75	0	2026-10-22 03:40:57.414+07	2026-10-22 03:40:57.919206+07
5046	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 03:40:57.909+07	2026-10-22 03:40:57.921479+07
5047	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	122	0	28.33	2026-10-22 03:40:59.187+07	2026-10-22 03:41:01.408686+07
5048	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	60	0	33.33	2026-10-22 03:40:58.948+07	2026-10-22 03:41:01.410437+07
5049	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	60	0	26.67	2026-10-22 03:40:58.952+07	2026-10-22 03:41:01.412155+07
5050	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	56	0	21.33	2026-10-22 03:40:58.956+07	2026-10-22 03:41:01.413825+07
5051	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	236	75	0	2026-10-22 03:41:01.405+07	2026-10-22 03:41:01.415556+07
5052	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	38	0	7.67	2026-10-22 03:41:02.353+07	2026-10-22 03:41:04.930824+07
5053	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	235	75	0	2026-10-22 03:41:04.92+07	2026-10-22 03:41:04.935841+07
5054	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	232	75	0	2026-10-22 03:41:04.92+07	2026-10-22 03:41:04.942212+07
5055	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	227	75	0	2026-10-22 03:41:04.92+07	2026-10-22 03:41:04.947874+07
3511	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	232	75	0	2026-10-22 01:29:20.416+07	2026-10-22 01:29:20.428201+07
3512	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	246	75	0	2026-10-22 01:29:20.416+07	2026-10-22 01:29:20.435076+07
4849	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	243	75	0	2026-10-22 03:25:02.928+07	2026-10-22 03:25:02.943261+07
4850	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	234	75	0	2026-10-22 03:25:02.927+07	2026-10-22 03:25:02.946601+07
4851	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	227	75	0	2026-10-22 03:25:02.928+07	2026-10-22 03:25:02.949726+07
4852	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	230	75	0	2026-10-22 03:25:02.928+07	2026-10-22 03:25:02.952333+07
4853	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	246	75	0	2026-10-22 03:25:06.416+07	2026-10-22 03:25:06.427355+07
4854	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	230	75	0	2026-10-22 03:25:06.416+07	2026-10-22 03:25:06.42975+07
4855	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	239	75	0	2026-10-22 03:25:06.416+07	2026-10-22 03:25:06.432162+07
4856	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	235	75	0	2026-10-22 03:25:06.416+07	2026-10-22 03:25:06.434092+07
4857	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	243	75	0	2026-10-22 03:25:06.416+07	2026-10-22 03:25:06.435937+07
4858	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	205	75	0	2026-10-22 03:25:09.917+07	2026-10-22 03:25:09.924753+07
4859	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	213	75	0	2026-10-22 03:25:09.916+07	2026-10-22 03:25:09.927854+07
4860	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	237	75	0	2026-10-22 03:25:09.917+07	2026-10-22 03:25:09.930521+07
4861	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	217	75	0	2026-10-22 03:25:09.916+07	2026-10-22 03:25:09.932685+07
4862	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	203	75	0	2026-10-22 03:25:09.916+07	2026-10-22 03:25:09.934642+07
4863	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	235	75	0	2026-10-22 03:25:13.415+07	2026-10-22 03:25:13.424188+07
4864	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	225	75	0	2026-10-22 03:25:13.415+07	2026-10-22 03:25:13.426994+07
4865	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	229	75	0	2026-10-22 03:25:13.415+07	2026-10-22 03:25:13.428823+07
4866	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	244	75	0	2026-10-22 03:25:13.415+07	2026-10-22 03:25:13.430426+07
4867	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	240	75	0	2026-10-22 03:25:13.415+07	2026-10-22 03:25:13.431982+07
4868	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	229	75	0	2026-10-22 03:25:16.904+07	2026-10-22 03:25:16.914756+07
4869	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	218	75	0	2026-10-22 03:25:16.905+07	2026-10-22 03:25:16.916833+07
4870	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	243	75	0	2026-10-22 03:25:16.905+07	2026-10-22 03:25:16.918907+07
4871	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	206	75	0	2026-10-22 03:25:16.905+07	2026-10-22 03:25:16.920552+07
4872	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	245	75	0	2026-10-22 03:25:16.905+07	2026-10-22 03:25:16.922208+07
4873	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	242	75	0	2026-10-22 03:25:20.41+07	2026-10-22 03:25:20.42107+07
4874	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	214	75	0	2026-10-22 03:25:20.411+07	2026-10-22 03:25:20.423249+07
4875	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	245	75	0	2026-10-22 03:25:20.411+07	2026-10-22 03:25:20.425644+07
4876	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	239	75	0	2026-10-22 03:25:20.411+07	2026-10-22 03:25:20.428012+07
4877	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	229	75	0	2026-10-22 03:25:20.411+07	2026-10-22 03:25:20.430095+07
4878	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	206	75	0	2026-10-22 03:25:23.909+07	2026-10-22 03:25:23.914676+07
4879	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	249	75	0	2026-10-22 03:25:23.909+07	2026-10-22 03:25:23.916618+07
4880	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	233	75	0	2026-10-22 03:25:23.909+07	2026-10-22 03:25:23.918275+07
4881	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	244	75	0	2026-10-22 03:25:23.909+07	2026-10-22 03:25:23.920006+07
4882	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	239	75	0	2026-10-22 03:25:23.909+07	2026-10-22 03:25:23.921887+07
4883	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	53	0	14.33	2026-10-22 03:25:24.922+07	2026-10-22 03:25:27.418807+07
4884	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	238	75	0	2026-10-22 03:25:27.412+07	2026-10-22 03:25:27.421405+07
4885	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	51	0	15	2026-10-22 03:25:24.916+07	2026-10-22 03:25:27.424535+07
4886	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	54	0	17.67	2026-10-22 03:25:24.928+07	2026-10-22 03:25:27.427224+07
4887	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	234	75	0	2026-10-22 03:25:27.412+07	2026-10-22 03:25:27.42988+07
4888	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	231	75	0	2026-10-22 03:25:30.916+07	2026-10-22 03:25:31.227233+07
4889	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	222	75	0	2026-10-22 03:25:30.916+07	2026-10-22 03:25:31.233929+07
4890	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	235	75	0	2026-10-22 03:25:30.916+07	2026-10-22 03:25:31.2372+07
4891	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	240	75	0	2026-10-22 03:25:30.916+07	2026-10-22 03:25:31.241894+07
4892	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	227	75	0	2026-10-22 03:25:30.916+07	2026-10-22 03:25:31.247183+07
4918	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	248	75	0	2026-10-22 03:25:52.915+07	2026-10-22 03:25:52.9203+07
4919	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	245	75	0	2026-10-22 03:25:52.915+07	2026-10-22 03:25:52.922099+07
4920	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	235	75	0	2026-10-22 03:25:52.915+07	2026-10-22 03:25:52.924551+07
4921	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	240	75	0	2026-10-22 03:25:52.915+07	2026-10-22 03:25:52.927625+07
4922	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	229	75	0	2026-10-22 03:25:52.915+07	2026-10-22 03:25:52.929622+07
4923	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	237	75	0	2026-10-22 03:25:56.416+07	2026-10-22 03:25:56.421961+07
4924	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	242	75	0	2026-10-22 03:25:56.416+07	2026-10-22 03:25:56.424777+07
4925	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	247	75	0	2026-10-22 03:25:56.415+07	2026-10-22 03:25:56.427404+07
4926	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	250	75	0	2026-10-22 03:25:56.411+07	2026-10-22 03:25:56.429763+07
4927	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	254	75	0	2026-10-22 03:25:56.416+07	2026-10-22 03:25:56.431778+07
5056	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	239	75	0	2026-10-22 03:41:04.92+07	2026-10-22 03:41:04.953334+07
3513	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	239	75	0	2026-10-22 01:29:23.91+07	2026-10-22 01:29:23.919816+07
3514	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	244	75	0	2026-10-22 01:29:23.91+07	2026-10-22 01:29:23.925983+07
3523	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	218	75	0	2026-10-22 01:29:41.408+07	2026-10-22 01:29:41.41567+07
3524	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	228	75	0	2026-10-22 01:29:41.408+07	2026-10-22 01:29:41.418834+07
3529	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	234	75	0	2026-10-22 01:29:51.915+07	2026-10-22 01:29:51.923703+07
3530	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	243	75	0	2026-10-22 01:29:51.915+07	2026-10-22 01:29:51.928519+07
3531	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	241	75	0	2026-10-22 01:29:55.403+07	2026-10-22 01:29:55.409295+07
3532	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	229	75	0	2026-10-22 01:29:55.403+07	2026-10-22 01:29:55.4123+07
3541	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	241	75	0	2026-10-22 01:30:12.901+07	2026-10-22 01:30:12.910058+07
3542	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	234	75	0	2026-10-22 01:30:12.901+07	2026-10-22 01:30:12.912251+07
3543	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	41	0	10.33	2026-10-22 01:30:13.844+07	2026-10-22 01:30:16.423106+07
3544	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	242	75	0	2026-10-22 01:30:16.416+07	2026-10-22 01:30:16.425058+07
3545	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	38	0	5.33	2026-10-22 01:30:17.361+07	2026-10-22 01:30:17.366027+07
3546	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	35	0	4.33	2026-10-22 01:30:17.362+07	2026-10-22 01:30:17.367767+07
3547	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	242	75	0	2026-10-22 01:30:20.912+07	2026-10-22 01:30:20.917283+07
3548	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	235	75	0	2026-10-22 01:30:20.912+07	2026-10-22 01:30:20.919047+07
3549	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	243	75	0	2026-10-22 01:30:24.416+07	2026-10-22 01:30:24.425386+07
3550	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	232	75	0	2026-10-22 01:30:24.416+07	2026-10-22 01:30:24.428565+07
3551	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	239	75	0	2026-10-22 01:30:27.915+07	2026-10-22 01:30:27.923421+07
3552	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	233	75	0	2026-10-22 01:30:27.915+07	2026-10-22 01:30:27.926994+07
3553	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	236	75	0	2026-10-22 01:30:31.405+07	2026-10-22 01:30:31.415524+07
3554	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	241	75	0	2026-10-22 01:30:31.404+07	2026-10-22 01:30:31.420722+07
3555	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	230	75	0	2026-10-22 01:30:34.902+07	2026-10-22 01:30:34.907327+07
3556	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	242	75	0	2026-10-22 01:30:34.902+07	2026-10-22 01:30:34.90906+07
3557	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	240	75	0	2026-10-22 01:30:38.415+07	2026-10-22 01:30:38.426054+07
3558	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	234	75	0	2026-10-22 01:30:38.415+07	2026-10-22 01:30:38.431069+07
3559	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	229	75	0	2026-10-22 01:30:41.908+07	2026-10-22 01:30:41.915676+07
3560	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	223	75	0	2026-10-22 01:30:41.908+07	2026-10-22 01:30:41.917957+07
3561	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	237	75	0	2026-10-22 01:30:45.413+07	2026-10-22 01:30:45.423845+07
3562	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	243	75	0	2026-10-22 01:30:45.414+07	2026-10-22 01:30:45.427942+07
3563	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	239	75	0	2026-10-22 01:30:48.904+07	2026-10-22 01:30:49.419209+07
3564	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 01:30:49.409+07	2026-10-22 01:30:49.424713+07
3565	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	236	75	0	2026-10-22 01:30:52.914+07	2026-10-22 01:30:52.918543+07
3566	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	231	75	0	2026-10-22 01:30:52.914+07	2026-10-22 01:30:52.920717+07
3567	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 01:30:56.908+07	2026-10-22 01:30:56.91236+07
3568	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	109	0	41.67	2026-10-22 01:30:54.135+07	2026-10-22 01:30:56.914033+07
3569	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	53	0	14.33	2026-10-22 01:30:57.907+07	2026-10-22 01:30:57.911228+07
3570	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	55	0	11	2026-10-22 01:30:57.903+07	2026-10-22 01:30:57.912924+07
3571	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	38	0	16	2026-10-22 01:30:58.851+07	2026-10-22 01:31:01.41377+07
3572	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	239	75	0	2026-10-22 01:31:01.41+07	2026-10-22 01:31:01.415411+07
3573	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	36	0	8	2026-10-22 01:31:02.36+07	2026-10-22 01:31:04.919643+07
3574	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	243	75	0	2026-10-22 01:31:04.911+07	2026-10-22 01:31:04.922788+07
3575	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	229	75	0	2026-10-22 01:31:08.409+07	2026-10-22 01:31:08.412575+07
3576	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	223	75	0	2026-10-22 01:31:08.409+07	2026-10-22 01:31:08.414186+07
3577	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-22 01:34:19.412+07	2026-10-22 01:34:19.42317+07
3578	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-22 01:37:26.921+07	2026-10-22 01:37:26.929716+07
3579	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	735	75	0	2026-10-22 01:37:48.407+07	2026-10-22 01:37:48.414796+07
3580	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	725	75	0	2026-10-22 01:37:48.407+07	2026-10-22 01:37:48.417175+07
3581	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	727	75	0	2026-10-22 01:37:52.409+07	2026-10-22 01:37:52.413861+07
3582	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	734	75	0	2026-10-22 01:37:52.409+07	2026-10-22 01:37:52.415841+07
3583	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	243	75	0	2026-10-22 01:37:55.916+07	2026-10-22 01:37:55.929756+07
3584	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	237	75	0	2026-10-22 01:37:55.916+07	2026-10-22 01:37:55.934358+07
3585	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	743	75	0	2026-10-22 01:37:59.916+07	2026-10-22 01:37:59.92052+07
3586	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	748	75	0	2026-10-22 01:37:59.916+07	2026-10-22 01:37:59.922832+07
3587	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	731	75	0	2026-10-22 01:38:03.915+07	2026-10-22 01:38:03.925328+07
3588	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	744	75	0	2026-10-22 01:38:03.915+07	2026-10-22 01:38:03.93096+07
3589	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	728	75	0	2026-10-22 01:38:07.907+07	2026-10-22 01:38:07.913645+07
3590	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	716	75	0	2026-10-22 01:38:07.907+07	2026-10-22 01:38:07.917712+07
3591	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	243	75	0	2026-10-22 01:38:11.409+07	2026-10-22 01:38:11.416693+07
3592	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	235	75	0	2026-10-22 01:38:11.409+07	2026-10-22 01:38:11.420628+07
3595	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	241	75	0	2026-10-22 01:38:18.407+07	2026-10-22 01:38:18.410982+07
3596	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	228	75	0	2026-10-22 01:38:18.407+07	2026-10-22 01:38:18.413681+07
3601	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	221	75	0	2026-10-22 01:38:28.917+07	2026-10-22 01:38:28.922425+07
3602	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	228	75	0	2026-10-22 01:38:28.917+07	2026-10-22 01:38:28.924622+07
3605	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	222	75	0	2026-10-22 01:38:35.914+07	2026-10-22 01:38:35.924672+07
3606	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	212	75	0	2026-10-22 01:38:35.914+07	2026-10-22 01:38:35.929554+07
3611	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	242	75	0	2026-10-22 01:38:46.411+07	2026-10-22 01:38:46.416075+07
3612	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	234	75	0	2026-10-22 01:38:46.411+07	2026-10-22 01:38:46.418152+07
3615	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	227	75	0	2026-10-22 01:38:53.407+07	2026-10-22 01:38:53.411695+07
3616	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	238	75	0	2026-10-22 01:38:53.407+07	2026-10-22 01:38:53.413724+07
3619	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	237	75	0	2026-10-22 01:39:00.404+07	2026-10-22 01:39:00.407693+07
3620	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	225	75	0	2026-10-22 01:39:00.404+07	2026-10-22 01:39:00.409295+07
3623	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	237	75	0	2026-10-22 01:39:07.413+07	2026-10-22 01:39:07.417157+07
3624	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	226	75	0	2026-10-22 01:39:07.413+07	2026-10-22 01:39:07.418709+07
3627	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	237	75	0	2026-10-22 01:39:14.41+07	2026-10-22 01:39:14.414682+07
3628	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	251	75	0	2026-10-22 01:39:14.41+07	2026-10-22 01:39:14.416564+07
3631	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	238	75	0	2026-10-22 01:39:21.41+07	2026-10-22 01:39:21.415978+07
3632	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	226	75	0	2026-10-22 01:39:21.41+07	2026-10-22 01:39:21.418013+07
3633	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	215	75	0	2026-10-22 01:39:24.909+07	2026-10-22 01:39:24.918969+07
3634	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	226	75	0	2026-10-22 01:39:24.91+07	2026-10-22 01:39:24.921808+07
3639	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	238	75	0	2026-10-22 01:39:35.4+07	2026-10-22 01:39:35.404132+07
3640	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	226	75	0	2026-10-22 01:39:35.4+07	2026-10-22 01:39:35.405731+07
3643	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	234	75	0	2026-10-22 01:39:42.404+07	2026-10-22 01:39:42.410721+07
3644	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	238	75	0	2026-10-22 01:39:42.404+07	2026-10-22 01:39:42.414703+07
3647	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	241	75	0	2026-10-22 01:39:49.407+07	2026-10-22 01:39:49.411887+07
3648	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	232	75	0	2026-10-22 01:39:49.407+07	2026-10-22 01:39:49.413841+07
3657	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	241	75	0	2026-10-22 01:40:06.9+07	2026-10-22 01:40:06.90499+07
3658	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	236	75	0	2026-10-22 01:40:06.9+07	2026-10-22 01:40:06.906755+07
3659	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	41	0	8	2026-10-22 01:40:07.854+07	2026-10-22 01:40:10.414614+07
3660	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	240	75	0	2026-10-22 01:40:10.41+07	2026-10-22 01:40:10.416168+07
3663	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	244	75	0	2026-10-22 01:40:14.904+07	2026-10-22 01:40:14.911609+07
3664	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	239	75	0	2026-10-22 01:40:14.903+07	2026-10-22 01:40:14.915513+07
3667	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	232	75	0	2026-10-22 01:40:21.904+07	2026-10-22 01:40:21.912638+07
3668	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	244	75	0	2026-10-22 01:40:21.904+07	2026-10-22 01:40:21.916608+07
3671	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	230	75	0	2026-10-22 01:40:27.414+07	2026-10-22 01:40:27.419769+07
3672	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	241	75	0	2026-10-22 01:40:27.414+07	2026-10-22 01:40:27.422208+07
3675	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	228	75	0	2026-10-22 01:40:34.405+07	2026-10-22 01:40:34.410198+07
3676	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	240	75	0	2026-10-22 01:40:34.405+07	2026-10-22 01:40:34.41222+07
3679	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	238	75	0	2026-10-22 01:40:41.407+07	2026-10-22 01:40:41.412637+07
3680	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	227	75	0	2026-10-22 01:40:41.407+07	2026-10-22 01:40:41.414579+07
3683	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	241	75	0	2026-10-22 01:40:48.4+07	2026-10-22 01:40:48.404539+07
3684	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	231	75	0	2026-10-22 01:40:48.4+07	2026-10-22 01:40:48.4061+07
3689	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	53	0	41.33	2026-10-22 01:40:56.414+07	2026-10-22 01:40:58.918158+07
3690	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	244	75	0	2026-10-22 01:40:58.911+07	2026-10-22 01:40:58.920681+07
4893	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	227	75	0	2026-10-22 03:25:34.91+07	2026-10-22 03:25:34.917209+07
4894	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	240	75	0	2026-10-22 03:25:34.91+07	2026-10-22 03:25:34.919389+07
4895	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	202	75	0	2026-10-22 03:25:34.91+07	2026-10-22 03:25:34.921171+07
4896	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	215	75	0	2026-10-22 03:25:34.91+07	2026-10-22 03:25:34.922811+07
4897	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	252	75	0	2026-10-22 03:25:34.91+07	2026-10-22 03:25:34.924897+07
4898	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	225	75	0	2026-10-22 03:25:38.403+07	2026-10-22 03:25:38.409151+07
4899	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	222	75	0	2026-10-22 03:25:38.403+07	2026-10-22 03:25:38.411306+07
4900	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	233	75	0	2026-10-22 03:25:38.403+07	2026-10-22 03:25:38.413097+07
4901	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	208	75	0	2026-10-22 03:25:38.403+07	2026-10-22 03:25:38.414877+07
4902	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	214	75	0	2026-10-22 03:25:38.403+07	2026-10-22 03:25:38.416763+07
4903	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	207	75	0	2026-10-22 03:25:41.903+07	2026-10-22 03:25:42.403296+07
4904	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 03:25:42.398+07	2026-10-22 03:25:42.405131+07
3593	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	62	0	38.33	2026-10-22 01:38:12.451+07	2026-10-22 01:38:14.91417+07
3594	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	245	75	0	2026-10-22 01:38:14.905+07	2026-10-22 01:38:14.91872+07
3597	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	47	0	26.67	2026-10-22 01:38:19.389+07	2026-10-22 01:38:21.920624+07
3598	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	240	75	0	2026-10-22 01:38:21.912+07	2026-10-22 01:38:21.925064+07
3599	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	238	75	0	2026-10-22 01:38:25.41+07	2026-10-22 01:38:25.416956+07
3600	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	244	75	0	2026-10-22 01:38:25.41+07	2026-10-22 01:38:25.420063+07
3603	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	227	75	0	2026-10-22 01:38:32.411+07	2026-10-22 01:38:32.415424+07
3604	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	238	75	0	2026-10-22 01:38:32.411+07	2026-10-22 01:38:32.417169+07
3607	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	239	75	0	2026-10-22 01:38:39.4+07	2026-10-22 01:38:39.403992+07
3608	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	199	75	0	2026-10-22 01:38:39.4+07	2026-10-22 01:38:39.405619+07
3609	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	239	75	0	2026-10-22 01:38:42.905+07	2026-10-22 01:38:42.908439+07
3610	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	228	75	0	2026-10-22 01:38:42.905+07	2026-10-22 01:38:42.910436+07
3613	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	244	75	0	2026-10-22 01:38:49.906+07	2026-10-22 01:38:49.916079+07
3614	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	237	75	0	2026-10-22 01:38:49.906+07	2026-10-22 01:38:49.920212+07
3617	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	217	75	0	2026-10-22 01:38:56.909+07	2026-10-22 01:38:56.918002+07
3618	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	227	75	0	2026-10-22 01:38:56.909+07	2026-10-22 01:38:56.921155+07
3621	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	253	75	0	2026-10-22 01:39:03.918+07	2026-10-22 01:39:03.92532+07
3622	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	256	75	0	2026-10-22 01:39:03.917+07	2026-10-22 01:39:03.929657+07
3625	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	233	75	0	2026-10-22 01:39:10.917+07	2026-10-22 01:39:10.923113+07
3626	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	243	75	0	2026-10-22 01:39:10.917+07	2026-10-22 01:39:10.925603+07
3629	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	241	75	0	2026-10-22 01:39:17.91+07	2026-10-22 01:39:17.916848+07
3630	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	233	75	0	2026-10-22 01:39:17.91+07	2026-10-22 01:39:17.919882+07
3635	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	241	75	0	2026-10-22 01:39:28.415+07	2026-10-22 01:39:28.422504+07
3636	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	230	75	0	2026-10-22 01:39:28.415+07	2026-10-22 01:39:28.427559+07
3637	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	246	75	0	2026-10-22 01:39:31.911+07	2026-10-22 01:39:31.928016+07
3638	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	233	75	0	2026-10-22 01:39:31.911+07	2026-10-22 01:39:31.932219+07
3641	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	233	75	0	2026-10-22 01:39:38.91+07	2026-10-22 01:39:38.916958+07
3642	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	245	75	0	2026-10-22 01:39:38.91+07	2026-10-22 01:39:38.919903+07
3645	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	233	75	0	2026-10-22 01:39:45.918+07	2026-10-22 01:39:45.926734+07
3646	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	244	75	0	2026-10-22 01:39:45.918+07	2026-10-22 01:39:45.930021+07
3649	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	232	75	0	2026-10-22 01:39:52.914+07	2026-10-22 01:39:52.919826+07
3650	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	245	75	0	2026-10-22 01:39:52.914+07	2026-10-22 01:39:52.922413+07
3651	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	237	75	0	2026-10-22 01:39:56.401+07	2026-10-22 01:39:56.408287+07
3652	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	227	75	0	2026-10-22 01:39:56.401+07	2026-10-22 01:39:56.411653+07
3653	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	238	75	0	2026-10-22 01:39:59.914+07	2026-10-22 01:39:59.921013+07
3654	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	231	75	0	2026-10-22 01:39:59.914+07	2026-10-22 01:39:59.922851+07
3655	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	232	75	0	2026-10-22 01:40:03.407+07	2026-10-22 01:40:03.411849+07
3656	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	238	75	0	2026-10-22 01:40:03.407+07	2026-10-22 01:40:03.413515+07
3661	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	46	0	15.67	2026-10-22 01:40:11.379+07	2026-10-22 01:40:11.388313+07
3662	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	42	0	8.33	2026-10-22 01:40:11.383+07	2026-10-22 01:40:11.390082+07
3665	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	238	75	0	2026-10-22 01:40:18.402+07	2026-10-22 01:40:18.407163+07
3666	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	227	75	0	2026-10-22 01:40:18.402+07	2026-10-22 01:40:18.409367+07
3669	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	229	75	0	2026-10-22 01:40:25.405+07	2026-10-22 01:40:25.412438+07
3670	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	240	75	0	2026-10-22 01:40:25.405+07	2026-10-22 01:40:25.41425+07
3673	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	248	75	0	2026-10-22 01:40:30.909+07	2026-10-22 01:40:30.922692+07
3674	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	243	75	0	2026-10-22 01:40:30.909+07	2026-10-22 01:40:30.928652+07
3677	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	232	75	0	2026-10-22 01:40:37.905+07	2026-10-22 01:40:37.919643+07
3678	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	244	75	0	2026-10-22 01:40:37.908+07	2026-10-22 01:40:37.924547+07
3681	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	242	75	0	2026-10-22 01:40:44.9+07	2026-10-22 01:40:44.906147+07
3682	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	247	75	0	2026-10-22 01:40:44.9+07	2026-10-22 01:40:44.908501+07
3685	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	45	0	14.33	2026-10-22 01:40:49.372+07	2026-10-22 01:40:51.92429+07
3686	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	227	75	0	2026-10-22 01:40:51.914+07	2026-10-22 01:40:51.930986+07
3687	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	226	75	0	2026-10-22 01:40:55.413+07	2026-10-22 01:40:55.417759+07
3688	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	236	75	0	2026-10-22 01:40:55.413+07	2026-10-22 01:40:55.419322+07
3691	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	238	75	0	2026-10-22 01:41:02.4+07	2026-10-22 01:41:02.40659+07
3692	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	227	75	0	2026-10-22 01:41:02.4+07	2026-10-22 01:41:02.409435+07
3693	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	238	75	0	2026-10-22 01:41:05.907+07	2026-10-22 01:41:05.918974+07
3694	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	248	75	0	2026-10-22 01:41:05.907+07	2026-10-22 01:41:05.922248+07
3695	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	233	75	0	2026-10-22 01:41:09.406+07	2026-10-22 01:41:09.411624+07
3696	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	238	75	0	2026-10-22 01:41:09.406+07	2026-10-22 01:41:09.413566+07
3697	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	233	75	0	2026-10-22 01:41:12.902+07	2026-10-22 01:41:12.907672+07
3698	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	238	75	0	2026-10-22 01:41:12.903+07	2026-10-22 01:41:12.909729+07
3699	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	248	75	0	2026-10-22 01:41:16.412+07	2026-10-22 01:41:16.420167+07
3700	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	252	75	0	2026-10-22 01:41:16.412+07	2026-10-22 01:41:16.422854+07
3701	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	232	75	0	2026-10-22 01:41:19.902+07	2026-10-22 01:41:19.91042+07
3702	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	237	75	0	2026-10-22 01:41:19.902+07	2026-10-22 01:41:19.912937+07
3703	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	236	75	0	2026-10-22 01:41:23.4+07	2026-10-22 01:41:23.404688+07
3704	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	232	75	0	2026-10-22 01:41:23.4+07	2026-10-22 01:41:23.406331+07
3705	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	241	75	0	2026-10-22 01:41:26.909+07	2026-10-22 01:41:26.913923+07
3706	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	247	75	0	2026-10-22 01:41:26.909+07	2026-10-22 01:41:26.915689+07
3707	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	239	75	0	2026-10-22 01:41:30.411+07	2026-10-22 01:41:30.419429+07
3708	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	228	75	0	2026-10-22 01:41:30.411+07	2026-10-22 01:41:30.423495+07
3709	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	239	75	0	2026-10-22 01:41:33.918+07	2026-10-22 01:41:33.922937+07
3710	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	231	75	0	2026-10-22 01:41:33.918+07	2026-10-22 01:41:33.924687+07
3713	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	225	75	0	2026-10-22 01:41:40.902+07	2026-10-22 01:41:40.908406+07
3714	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	237	75	0	2026-10-22 01:41:40.902+07	2026-10-22 01:41:40.911022+07
3715	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	244	75	0	2026-10-22 01:41:44.412+07	2026-10-22 01:41:44.41636+07
3716	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	249	75	0	2026-10-22 01:41:44.412+07	2026-10-22 01:41:44.417978+07
3717	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	240	75	0	2026-10-22 01:41:47.9+07	2026-10-22 01:41:47.905888+07
3718	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	235	75	0	2026-10-22 01:41:47.9+07	2026-10-22 01:41:47.90871+07
3719	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	219	75	0	2026-10-22 01:41:51.411+07	2026-10-22 01:41:51.419076+07
3720	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	231	75	0	2026-10-22 01:41:51.411+07	2026-10-22 01:41:51.424133+07
3721	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	238	75	0	2026-10-22 01:41:54.911+07	2026-10-22 01:41:54.914906+07
3722	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	233	75	0	2026-10-22 01:41:54.911+07	2026-10-22 01:41:54.916832+07
3723	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	235	75	0	2026-10-22 01:41:58.414+07	2026-10-22 01:41:58.418395+07
3724	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	238	75	0	2026-10-22 01:41:58.414+07	2026-10-22 01:41:58.420175+07
3735	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	223	75	0	2026-10-22 01:42:12.402+07	2026-10-22 01:42:12.405896+07
3736	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	227	75	0	2026-10-22 01:42:12.402+07	2026-10-22 01:42:12.407494+07
3739	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	250	75	0	2026-10-22 01:42:15.924+07	2026-10-22 01:42:15.938087+07
3740	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	257	75	0	2026-10-22 01:42:15.924+07	2026-10-22 01:42:15.948451+07
3741	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	248	75	0	2026-10-22 01:42:18.92+07	2026-10-22 01:42:18.930657+07
3742	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	230	75	0	2026-10-22 01:42:19.414+07	2026-10-22 01:42:19.417467+07
3743	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	240	75	0	2026-10-22 01:42:19.414+07	2026-10-22 01:42:19.419082+07
3744	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	236	75	0	2026-10-22 01:42:21.912+07	2026-10-22 01:42:21.921764+07
3745	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	226	75	0	2026-10-22 01:42:22.918+07	2026-10-22 01:42:22.932338+07
3746	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	247	75	0	2026-10-22 01:42:22.915+07	2026-10-22 01:42:22.937128+07
3747	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	247	75	0	2026-10-22 01:42:24.916+07	2026-10-22 01:42:24.927414+07
3748	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	239	75	0	2026-10-22 01:42:26.409+07	2026-10-22 01:42:26.413585+07
3749	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	234	75	0	2026-10-22 01:42:26.409+07	2026-10-22 01:42:26.415449+07
3750	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	\N	100	0	2026-10-22 01:42:28.416+07	2026-10-22 01:42:28.419916+07
3751	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	240	75	0	2026-10-22 01:42:29.922+07	2026-10-22 01:42:29.932922+07
3752	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	234	75	0	2026-10-22 01:42:29.922+07	2026-10-22 01:42:29.937684+07
3753	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	245	75	0	2026-10-22 01:42:30.913+07	2026-10-22 01:42:30.924975+07
3754	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	235	75	0	2026-10-22 01:42:33.412+07	2026-10-22 01:42:33.415801+07
3755	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	241	75	0	2026-10-22 01:42:33.412+07	2026-10-22 01:42:33.41746+07
3756	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	242	75	0	2026-10-22 01:42:33.918+07	2026-10-22 01:42:33.927826+07
3757	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	244	75	0	2026-10-22 01:42:36.922+07	2026-10-22 01:42:36.932567+07
4905	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	246	75	0	2026-10-22 03:25:41.903+07	2026-10-22 03:25:42.407064+07
4906	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	242	75	0	2026-10-22 03:25:41.903+07	2026-10-22 03:25:42.409165+07
4907	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 03:25:42.398+07	2026-10-22 03:25:42.411807+07
4908	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	142	0	32.67	2026-10-22 03:25:43.739+07	2026-10-22 03:25:45.921924+07
4909	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	55	0	18	2026-10-22 03:25:43.403+07	2026-10-22 03:25:45.925594+07
4910	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	51	0	17.33	2026-10-22 03:25:43.41+07	2026-10-22 03:25:45.929291+07
4911	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	56	0	13.33	2026-10-22 03:25:43.422+07	2026-10-22 03:25:45.932798+07
4912	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	242	75	0	2026-10-22 03:25:45.915+07	2026-10-22 03:25:45.935554+07
4913	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	56	0	18.67	2026-10-22 03:25:46.95+07	2026-10-22 03:25:49.421439+07
3711	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	239	75	0	2026-10-22 01:41:37.41+07	2026-10-22 01:41:37.414874+07
3712	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	233	75	0	2026-10-22 01:41:37.41+07	2026-10-22 01:41:37.416858+07
3725	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	224	75	0	2026-10-22 01:42:00.919+07	2026-10-22 01:42:00.929693+07
3726	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	226	75	0	2026-10-22 01:42:01.905+07	2026-10-22 01:42:01.913098+07
3727	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	216	75	0	2026-10-22 01:42:01.905+07	2026-10-22 01:42:01.916258+07
3728	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	208	75	0	2026-10-22 01:42:03.904+07	2026-10-22 01:42:03.908598+07
3729	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	238	75	0	2026-10-22 01:42:05.406+07	2026-10-22 01:42:05.410378+07
3730	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	222	75	0	2026-10-22 01:42:05.406+07	2026-10-22 01:42:05.412089+07
3731	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	239	75	0	2026-10-22 01:42:06.916+07	2026-10-22 01:42:06.928224+07
3732	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	234	75	0	2026-10-22 01:42:08.92+07	2026-10-22 01:42:08.930363+07
3733	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	246	75	0	2026-10-22 01:42:08.919+07	2026-10-22 01:42:08.934895+07
3734	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	222	75	0	2026-10-22 01:42:09.92+07	2026-10-22 01:42:09.930689+07
3737	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	241	75	0	2026-10-22 01:42:12.907+07	2026-10-22 01:42:12.913442+07
3738	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	240	75	0	2026-10-22 01:42:15.922+07	2026-10-22 01:42:15.932826+07
3758	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	233	75	0	2026-10-22 01:42:36.923+07	2026-10-22 01:42:36.939592+07
3759	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	219	75	0	2026-10-22 01:42:36.924+07	2026-10-22 01:42:36.948038+07
3760	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	72	0	41.33	2026-10-22 01:42:37.616+07	2026-10-22 01:42:37.626472+07
3761	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	222	75	0	2026-10-22 01:42:40.408+07	2026-10-22 01:42:40.411816+07
3762	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	229	75	0	2026-10-22 01:42:40.408+07	2026-10-22 01:42:40.413567+07
3763	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	243	75	0	2026-10-22 01:42:42.912+07	2026-10-22 01:42:42.923866+07
3764	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	241	75	0	2026-10-22 01:42:43.908+07	2026-10-22 01:42:43.912221+07
3765	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	247	75	0	2026-10-22 01:42:43.908+07	2026-10-22 01:42:43.913959+07
3766	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	\N	100	0	2026-10-22 01:42:46.411+07	2026-10-22 01:42:46.414529+07
3767	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	57	0	9.67	2026-10-22 01:42:44.929+07	2026-10-22 01:42:47.416605+07
3768	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	240	75	0	2026-10-22 01:42:47.413+07	2026-10-22 01:42:47.418076+07
3769	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	51	0	22.67	2026-10-22 01:42:48.391+07	2026-10-22 01:42:48.395006+07
3770	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	47	0	26	2026-10-22 01:42:48.389+07	2026-10-22 01:42:48.39672+07
3771	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	\N	100	0	2026-10-22 01:42:49.409+07	2026-10-22 01:42:49.416284+07
3772	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	60	0	35.67	2026-10-22 01:42:49.641+07	2026-10-22 01:42:49.644804+07
3773	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	244	75	0	2026-10-22 01:42:51.91+07	2026-10-22 01:42:51.919785+07
3774	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	241	75	0	2026-10-22 01:42:51.91+07	2026-10-22 01:42:51.92563+07
3775	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	249	75	0	2026-10-22 01:42:54.909+07	2026-10-22 01:42:54.919079+07
3776	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	229	75	0	2026-10-22 01:42:55.415+07	2026-10-22 01:42:55.426166+07
3777	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	237	75	0	2026-10-22 01:42:55.414+07	2026-10-22 01:42:55.431399+07
3778	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	244	75	0	2026-10-22 01:42:57.913+07	2026-10-22 01:42:57.925174+07
3779	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	224	75	0	2026-10-22 01:42:58.918+07	2026-10-22 01:42:58.930106+07
3780	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	245	75	0	2026-10-22 01:42:58.917+07	2026-10-22 01:42:58.935117+07
3781	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	234	75	0	2026-10-22 01:43:00.921+07	2026-10-22 01:43:00.933425+07
3782	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	232	75	0	2026-10-22 01:43:02.402+07	2026-10-22 01:43:02.41225+07
3783	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	238	75	0	2026-10-22 01:43:02.402+07	2026-10-22 01:43:02.416328+07
3784	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	221	75	0	2026-10-22 01:43:03.91+07	2026-10-22 01:43:03.918623+07
3785	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	237	75	0	2026-10-22 01:43:05.918+07	2026-10-22 01:43:05.93842+07
3786	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	241	75	0	2026-10-22 01:43:05.918+07	2026-10-22 01:43:05.945757+07
3787	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	245	75	0	2026-10-22 01:43:06.902+07	2026-10-22 01:43:06.909954+07
3788	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	242	75	0	2026-10-22 01:43:09.417+07	2026-10-22 01:43:09.423572+07
3789	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	230	75	0	2026-10-22 01:43:09.417+07	2026-10-22 01:43:09.42703+07
3790	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	236	75	0	2026-10-22 01:43:09.906+07	2026-10-22 01:43:09.912039+07
3791	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	229	75	0	2026-10-22 01:43:12.904+07	2026-10-22 01:43:12.909921+07
3792	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	238	75	0	2026-10-22 01:43:12.905+07	2026-10-22 01:43:12.911646+07
3793	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	233	75	0	2026-10-22 01:43:12.904+07	2026-10-22 01:43:12.91201+07
3794	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	239	75	0	2026-10-22 01:43:15.908+07	2026-10-22 01:43:15.91255+07
3795	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	235	75	0	2026-10-22 01:43:16.408+07	2026-10-22 01:43:16.41456+07
3796	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	225	75	0	2026-10-22 01:43:16.409+07	2026-10-22 01:43:16.41703+07
3797	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	240	75	0	2026-10-22 01:43:18.913+07	2026-10-22 01:43:18.918535+07
3798	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	237	75	0	2026-10-22 01:43:19.917+07	2026-10-22 01:43:20.418179+07
3799	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 01:43:20.413+07	2026-10-22 01:43:20.42026+07
3800	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	240	75	0	2026-10-22 01:43:21.904+07	2026-10-22 01:43:21.908668+07
3801	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	241	75	0	2026-10-22 01:43:23.912+07	2026-10-22 01:43:23.920644+07
3802	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	234	75	0	2026-10-22 01:43:23.913+07	2026-10-22 01:43:23.924228+07
3803	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	239	75	0	2026-10-22 01:43:24.915+07	2026-10-22 01:43:24.921912+07
3804	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	244	75	0	2026-10-22 01:43:27.904+07	2026-10-22 01:43:27.909071+07
3807	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	47	0	10.33	2026-10-22 01:43:28.89+07	2026-10-22 01:43:28.898281+07
3808	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	43	0	5.67	2026-10-22 01:43:28.893+07	2026-10-22 01:43:28.900326+07
3809	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	259	75	0	2026-10-22 01:43:30.913+07	2026-10-22 01:43:30.918324+07
3810	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	50	0	19.67	2026-10-22 01:43:29.886+07	2026-10-22 01:43:32.407451+07
3811	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	233	75	0	2026-10-22 01:43:32.403+07	2026-10-22 01:43:32.408966+07
3812	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	236	75	0	2026-10-22 01:43:33.916+07	2026-10-22 01:43:33.927549+07
3813	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	43	0	13.33	2026-10-22 01:43:33.373+07	2026-10-22 01:43:35.909751+07
3814	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	228	75	0	2026-10-22 01:43:35.905+07	2026-10-22 01:43:35.911367+07
3815	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	221	75	0	2026-10-22 01:43:36.909+07	2026-10-22 01:43:36.913296+07
3816	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	235	75	0	2026-10-22 01:43:39.4+07	2026-10-22 01:43:39.404774+07
3817	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	239	75	0	2026-10-22 01:43:39.4+07	2026-10-22 01:43:39.406407+07
3818	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	240	75	0	2026-10-22 01:43:39.905+07	2026-10-22 01:43:39.910729+07
4914	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	246	75	0	2026-10-22 03:25:49.415+07	2026-10-22 03:25:49.424705+07
4915	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	250	75	0	2026-10-22 03:25:49.416+07	2026-10-22 03:25:49.427291+07
4916	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	238	75	0	2026-10-22 03:25:49.416+07	2026-10-22 03:25:49.429335+07
4917	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	242	75	0	2026-10-22 03:25:49.415+07	2026-10-22 03:25:49.431028+07
5057	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	224	75	0	2026-10-22 03:41:08.411+07	2026-10-22 03:41:08.414994+07
5058	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	203	75	0	2026-10-22 03:41:08.41+07	2026-10-22 03:41:08.416731+07
5059	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	195	75	0	2026-10-22 03:41:08.411+07	2026-10-22 03:41:08.418588+07
5060	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	211	75	0	2026-10-22 03:41:08.41+07	2026-10-22 03:41:08.420316+07
5061	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	236	75	0	2026-10-22 03:41:08.411+07	2026-10-22 03:41:08.422601+07
5212	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	737	75	0	2026-10-22 03:45:27.407+07	2026-10-22 03:45:27.418904+07
5213	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	724	75	0	2026-10-22 03:45:31.407+07	2026-10-22 03:45:31.411725+07
5214	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	719	75	0	2026-10-22 03:45:31.407+07	2026-10-22 03:45:31.414091+07
5215	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	729	75	0	2026-10-22 03:45:31.407+07	2026-10-22 03:45:31.416369+07
5216	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	738	75	0	2026-10-22 03:45:31.407+07	2026-10-22 03:45:31.41834+07
5217	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	734	75	0	2026-10-22 03:45:31.407+07	2026-10-22 03:45:31.420266+07
5218	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	742	75	0	2026-10-22 03:45:35.414+07	2026-10-22 03:45:35.423889+07
5219	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	724	75	0	2026-10-22 03:45:35.414+07	2026-10-22 03:45:35.428093+07
5220	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	733	75	0	2026-10-22 03:45:35.414+07	2026-10-22 03:45:35.435431+07
5221	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	717	75	0	2026-10-22 03:45:35.414+07	2026-10-22 03:45:35.439246+07
5222	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	749	75	0	2026-10-22 03:45:35.413+07	2026-10-22 03:45:35.442635+07
5223	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	742	75	0	2026-10-22 03:45:39.41+07	2026-10-22 03:45:39.41465+07
5224	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	719	75	0	2026-10-22 03:45:39.409+07	2026-10-22 03:45:39.416674+07
5225	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	713	75	0	2026-10-22 03:45:39.409+07	2026-10-22 03:45:39.418386+07
5226	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	727	75	0	2026-10-22 03:45:39.409+07	2026-10-22 03:45:39.420367+07
5227	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	735	75	0	2026-10-22 03:45:39.409+07	2026-10-22 03:45:39.422316+07
5228	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	740	75	0	2026-10-22 03:45:43.416+07	2026-10-22 03:45:43.420968+07
5229	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	744	75	0	2026-10-22 03:45:43.416+07	2026-10-22 03:45:43.422769+07
5230	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	747	75	0	2026-10-22 03:45:43.416+07	2026-10-22 03:45:43.424529+07
5231	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	731	75	0	2026-10-22 03:45:43.416+07	2026-10-22 03:45:43.426193+07
5232	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	736	75	0	2026-10-22 03:45:43.416+07	2026-10-22 03:45:43.428883+07
5233	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	719	75	0	2026-10-22 03:45:47.403+07	2026-10-22 03:45:47.407541+07
5234	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	705	75	0	2026-10-22 03:45:47.403+07	2026-10-22 03:45:47.409304+07
5235	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	732	75	0	2026-10-22 03:45:47.403+07	2026-10-22 03:45:47.411153+07
5236	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	742	75	0	2026-10-22 03:45:47.403+07	2026-10-22 03:45:47.41361+07
5237	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	693	75	0	2026-10-22 03:45:47.403+07	2026-10-22 03:45:47.415771+07
5238	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	741	75	0	2026-10-22 03:45:51.41+07	2026-10-22 03:45:51.416911+07
5239	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	730	75	0	2026-10-22 03:45:51.41+07	2026-10-22 03:45:51.420074+07
5240	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	198	75	0	2026-10-22 03:45:50.906+07	2026-10-22 03:45:51.422663+07
5241	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	235	75	0	2026-10-22 03:45:50.906+07	2026-10-22 03:45:51.425246+07
5242	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	249	75	0	2026-10-22 03:45:50.906+07	2026-10-22 03:45:51.427449+07
5243	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	231	75	0	2026-10-22 03:45:54.921+07	2026-10-22 03:45:54.928308+07
5244	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	219	75	0	2026-10-22 03:45:54.921+07	2026-10-22 03:45:54.933632+07
3805	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 01:43:27.905+07	2026-10-22 01:43:27.910107+07
3806	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	80	0	69.67	2026-10-22 01:43:25.022+07	2026-10-22 01:43:27.912838+07
3819	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	238	75	0	2026-10-22 01:43:42.901+07	2026-10-22 01:43:42.906259+07
3820	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	246	75	0	2026-10-22 01:43:45.934+07	2026-10-22 01:43:45.940115+07
3821	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	239	75	0	2026-10-22 01:43:48.904+07	2026-10-22 01:43:48.912294+07
3822	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	235	75	0	2026-10-22 01:43:51.904+07	2026-10-22 01:43:51.910691+07
3823	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	243	75	0	2026-10-22 01:43:54.913+07	2026-10-22 01:43:54.917913+07
3824	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	230	75	0	2026-10-22 01:43:57.909+07	2026-10-22 01:43:57.913572+07
3825	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	236	75	0	2026-10-22 01:44:00.907+07	2026-10-22 01:44:00.912971+07
3826	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	237	75	0	2026-10-22 01:44:03.906+07	2026-10-22 01:44:03.911852+07
3827	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	220	75	0	2026-10-22 01:44:06.902+07	2026-10-22 01:44:06.907202+07
3828	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	247	75	0	2026-10-22 01:44:09.913+07	2026-10-22 01:44:09.917253+07
3829	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	237	75	0	2026-10-22 01:44:15.909+07	2026-10-22 01:44:15.913838+07
3830	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	\N	100	0	2026-10-22 01:44:19.404+07	2026-10-22 01:44:19.408724+07
3831	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	239	75	0	2026-10-22 01:44:21.911+07	2026-10-22 01:44:21.915168+07
3832	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	238	75	0	2026-10-22 01:44:25.409+07	2026-10-22 01:44:25.413867+07
3833	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	\N	100	0	2026-10-22 01:44:28.908+07	2026-10-22 01:44:28.912674+07
3834	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	239	75	0	2026-10-22 01:44:31.412+07	2026-10-22 01:44:31.416576+07
3835	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	239	75	0	2026-10-22 01:44:34.403+07	2026-10-22 01:44:34.407592+07
3836	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	245	75	0	2026-10-22 01:44:37.408+07	2026-10-22 01:44:37.413194+07
3837	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	237	75	0	2026-10-22 01:44:40.4+07	2026-10-22 01:44:40.404855+07
3838	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	236	75	0	2026-10-22 01:44:43.411+07	2026-10-22 01:44:43.41582+07
3839	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	238	75	0	2026-10-22 01:44:46.406+07	2026-10-22 01:44:46.410787+07
3840	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	238	75	0	2026-10-22 01:44:49.411+07	2026-10-22 01:44:49.415341+07
3841	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	237	75	0	2026-10-22 01:44:52.411+07	2026-10-22 01:44:52.416169+07
3842	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	238	75	0	2026-10-22 01:44:55.412+07	2026-10-22 01:44:55.416913+07
3843	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	239	75	0	2026-10-22 01:44:58.405+07	2026-10-22 01:44:58.40914+07
3844	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	240	75	0	2026-10-22 01:45:01.407+07	2026-10-22 01:45:01.412851+07
3845	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	239	75	0	2026-10-22 01:45:04.418+07	2026-10-22 01:45:04.426765+07
3846	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	235	75	0	2026-10-22 01:45:07.41+07	2026-10-22 01:45:07.414515+07
3847	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	238	75	0	2026-10-22 01:45:10.406+07	2026-10-22 01:45:10.410589+07
3848	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	238	75	0	2026-10-22 01:45:13.412+07	2026-10-22 01:45:13.416866+07
3849	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	238	75	0	2026-10-22 01:45:16.416+07	2026-10-22 01:45:16.422994+07
3850	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	236	75	0	2026-10-22 01:45:19.403+07	2026-10-22 01:45:19.407521+07
3851	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	236	75	0	2026-10-22 01:45:22.407+07	2026-10-22 01:45:22.411617+07
3852	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	238	75	0	2026-10-22 01:45:25.406+07	2026-10-22 01:45:25.410151+07
3853	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	241	75	0	2026-10-22 01:45:28.401+07	2026-10-22 01:45:28.405869+07
3854	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	238	75	0	2026-10-22 01:45:31.41+07	2026-10-22 01:45:31.41408+07
3855	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	237	75	0	2026-10-22 01:45:34.4+07	2026-10-22 01:45:34.404956+07
3856	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	240	75	0	2026-10-22 01:45:37.402+07	2026-10-22 01:45:37.406681+07
3857	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	238	75	0	2026-10-22 01:45:40.414+07	2026-10-22 01:45:40.425025+07
3858	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	240	75	0	2026-10-22 01:45:43.406+07	2026-10-22 01:45:43.410248+07
3859	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	241	75	0	2026-10-22 01:45:46.411+07	2026-10-22 01:45:46.414994+07
3860	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	240	75	0	2026-10-22 01:45:49.41+07	2026-10-22 01:45:49.415169+07
3861	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	237	75	0	2026-10-22 01:45:52.405+07	2026-10-22 01:45:52.409322+07
3862	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	240	75	0	2026-10-22 01:45:55.415+07	2026-10-22 01:45:55.419918+07
3863	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	262	75	0	2026-10-22 01:45:58.413+07	2026-10-22 01:45:58.416971+07
3864	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	39	0	8.67	2026-10-22 01:45:59.075+07	2026-10-22 01:45:59.079135+07
3865	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	240	75	0	2026-10-22 01:46:04.416+07	2026-10-22 01:46:04.424728+07
3866	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	57	0	32	2026-10-22 01:46:05.173+07	2026-10-22 01:46:05.177222+07
3867	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	48	0	19.67	2026-10-22 01:46:08.126+07	2026-10-22 01:46:08.129826+07
3868	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	228	75	0	2026-10-22 01:46:11.911+07	2026-10-22 01:46:12.411346+07
3869	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	737	75	0	2026-10-22 01:46:13.92+07	2026-10-22 01:46:13.929314+07
3870	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	239	75	0	2026-10-22 01:46:15.919+07	2026-10-22 01:46:15.930506+07
3871	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	\N	100	0	2026-10-22 01:46:16.908+07	2026-10-22 01:46:16.914618+07
3872	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	232	75	0	2026-10-22 01:46:19.404+07	2026-10-22 01:46:19.408353+07
3873	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	740	75	0	2026-10-22 01:46:19.909+07	2026-10-22 01:46:19.92194+07
3874	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	240	75	0	2026-10-22 01:46:22.413+07	2026-10-22 01:46:22.41896+07
3875	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	741	75	0	2026-10-22 01:46:25.916+07	2026-10-22 01:46:25.922914+07
3876	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	730	75	0	2026-10-22 01:46:28.912+07	2026-10-22 01:46:28.923429+07
3877	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	712	75	0	2026-10-22 01:46:31.919+07	2026-10-22 01:46:31.929305+07
3878	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	\N	100	0	2026-10-22 01:46:34.902+07	2026-10-22 01:46:34.912743+07
3879	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	746	75	0	2026-10-22 01:46:37.919+07	2026-10-22 01:46:37.929101+07
3880	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	729	75	0	2026-10-22 01:46:40.913+07	2026-10-22 01:46:40.922627+07
3881	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	719	75	0	2026-10-22 01:46:43.902+07	2026-10-22 01:46:43.908479+07
3882	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	746	75	0	2026-10-22 01:46:46.91+07	2026-10-22 01:46:46.920236+07
3883	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	\N	100	0	2026-10-22 01:46:49.916+07	2026-10-22 01:46:49.926361+07
3884	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	745	75	0	2026-10-22 01:46:52.908+07	2026-10-22 01:46:52.916794+07
3885	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	\N	100	0	2026-10-22 01:46:55.922+07	2026-10-22 01:46:55.933331+07
3886	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	\N	100	0	2026-10-22 01:46:58.92+07	2026-10-22 01:46:58.926132+07
3887	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	729	75	0	2026-10-22 01:47:01.907+07	2026-10-22 01:47:01.915413+07
3888	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	219	75	0	2026-10-22 01:47:04.406+07	2026-10-22 01:47:04.411316+07
3889	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 01:47:04.911+07	2026-10-22 01:47:04.921643+07
3890	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	741	75	0	2026-10-22 01:47:07.912+07	2026-10-22 01:47:07.918586+07
3891	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	\N	100	0	2026-10-22 01:47:10.909+07	2026-10-22 01:47:10.917059+07
3892	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 01:47:13.904+07	2026-10-22 01:47:13.912769+07
3893	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	152	0	7.67	2026-10-22 01:47:14.702+07	2026-10-22 01:47:14.709414+07
3894	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	57	0	33	2026-10-22 01:47:17.346+07	2026-10-22 01:47:17.351424+07
3895	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	42	0	13	2026-10-22 01:47:20.28+07	2026-10-22 01:47:20.284542+07
3896	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	66	0	25	2026-10-22 01:47:23.382+07	2026-10-22 01:47:23.387325+07
3897	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	727	75	0	2026-10-22 01:47:28.905+07	2026-10-22 01:47:28.915302+07
3898	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	67	0	34.33	2026-10-22 01:47:29.412+07	2026-10-22 01:47:29.417991+07
3899	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	\N	100	0	2026-10-22 01:47:35.413+07	2026-10-22 01:47:35.421175+07
3900	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	\N	100	0	2026-10-22 01:47:38.406+07	2026-10-22 01:47:38.414595+07
3901	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	724	75	0	2026-10-22 01:47:41.4+07	2026-10-22 01:47:41.404277+07
3902	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	232	75	0	2026-10-22 01:47:45.91+07	2026-10-22 01:47:45.92188+07
3903	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	245	75	0	2026-10-22 01:47:45.91+07	2026-10-22 01:47:45.927039+07
3904	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	736	75	0	2026-10-22 01:47:47.407+07	2026-10-22 01:47:47.412078+07
3905	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	234	75	0	2026-10-22 01:47:46.91+07	2026-10-22 01:47:47.414166+07
3906	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	739	75	0	2026-10-22 01:47:51.404+07	2026-10-22 01:47:51.40869+07
3907	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	727	75	0	2026-10-22 01:47:51.404+07	2026-10-22 01:47:51.410877+07
3908	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	736	75	0	2026-10-22 01:47:55.409+07	2026-10-22 01:47:55.413909+07
3909	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	724	75	0	2026-10-22 01:47:55.409+07	2026-10-22 01:47:55.416146+07
3910	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	737	75	0	2026-10-22 01:47:59.412+07	2026-10-22 01:47:59.417846+07
3911	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	726	75	0	2026-10-22 01:47:59.412+07	2026-10-22 01:47:59.420129+07
3912	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	727	75	0	2026-10-22 01:48:03.403+07	2026-10-22 01:48:03.40931+07
3913	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	737	75	0	2026-10-22 01:48:03.404+07	2026-10-22 01:48:03.411938+07
3914	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	731	75	0	2026-10-22 01:48:07.407+07	2026-10-22 01:48:07.414521+07
3915	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	737	75	0	2026-10-22 01:48:07.407+07	2026-10-22 01:48:07.416878+07
3916	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	735	75	0	2026-10-22 01:48:11.399+07	2026-10-22 01:48:11.403233+07
3917	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	44	0	8.33	2026-10-22 01:48:08.377+07	2026-10-22 01:48:11.404779+07
3918	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	730	75	0	2026-10-22 01:48:15.413+07	2026-10-22 01:48:15.417008+07
3919	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	738	75	0	2026-10-22 01:48:15.413+07	2026-10-22 01:48:15.418616+07
3920	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	739	75	0	2026-10-22 01:48:19.405+07	2026-10-22 01:48:19.409731+07
3921	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	45	0	14.67	2026-10-22 01:48:16.389+07	2026-10-22 01:48:19.411291+07
3922	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	731	75	0	2026-10-22 01:48:23.417+07	2026-10-22 01:48:23.423144+07
3923	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	743	75	0	2026-10-22 01:48:23.417+07	2026-10-22 01:48:23.425661+07
3924	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	732	75	0	2026-10-22 01:48:27.411+07	2026-10-22 01:48:27.417421+07
3925	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	739	75	0	2026-10-22 01:48:27.411+07	2026-10-22 01:48:27.419185+07
3926	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	722	75	0	2026-10-22 01:48:31.407+07	2026-10-22 01:48:31.411575+07
3927	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	733	75	0	2026-10-22 01:48:31.407+07	2026-10-22 01:48:31.413737+07
3928	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	748	75	0	2026-10-22 01:48:35.414+07	2026-10-22 01:48:35.419323+07
3929	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	739	75	0	2026-10-22 01:48:35.414+07	2026-10-22 01:48:35.420943+07
3930	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	235	75	0	2026-10-22 01:48:38.911+07	2026-10-22 01:48:38.916033+07
3931	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	247	75	0	2026-10-22 01:48:38.911+07	2026-10-22 01:48:38.917892+07
4928	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	228	75	0	2026-10-22 03:27:22.4+07	2026-10-22 03:27:22.407798+07
3932	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	244	75	0	2026-10-22 01:48:42.404+07	2026-10-22 01:48:42.408473+07
3933	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	232	75	0	2026-10-22 01:48:42.404+07	2026-10-22 01:48:42.410173+07
3934	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	240	75	0	2026-10-22 01:48:45.905+07	2026-10-22 01:48:45.910676+07
3935	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	229	75	0	2026-10-22 01:48:45.905+07	2026-10-22 01:48:45.913512+07
3936	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	232	75	0	2026-10-22 01:48:49.408+07	2026-10-22 01:48:49.414326+07
3937	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	236	75	0	2026-10-22 01:48:49.408+07	2026-10-22 01:48:49.417085+07
3938	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	247	75	0	2026-10-22 01:48:52.916+07	2026-10-22 01:48:52.921981+07
3939	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	236	75	0	2026-10-22 01:48:52.916+07	2026-10-22 01:48:52.926045+07
3940	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	241	75	0	2026-10-22 01:48:56.401+07	2026-10-22 01:48:56.404877+07
3941	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	237	75	0	2026-10-22 01:48:56.401+07	2026-10-22 01:48:56.406432+07
3942	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	239	75	0	2026-10-22 01:48:59.908+07	2026-10-22 01:48:59.924334+07
3943	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	245	75	0	2026-10-22 01:48:59.908+07	2026-10-22 01:48:59.92758+07
3944	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	239	75	0	2026-10-22 01:49:03.414+07	2026-10-22 01:49:03.419856+07
3945	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	231	75	0	2026-10-22 01:49:03.414+07	2026-10-22 01:49:03.421734+07
3946	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	237	75	0	2026-10-22 01:49:06.899+07	2026-10-22 01:49:06.903178+07
3947	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	227	75	0	2026-10-22 01:49:06.899+07	2026-10-22 01:49:06.904861+07
3948	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	237	75	0	2026-10-22 01:49:10.411+07	2026-10-22 01:49:10.41509+07
3949	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	226	75	0	2026-10-22 01:49:10.411+07	2026-10-22 01:49:10.416899+07
3950	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	244	75	0	2026-10-22 01:49:13.908+07	2026-10-22 01:49:13.914396+07
3951	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	234	75	0	2026-10-22 01:49:13.908+07	2026-10-22 01:49:13.918281+07
3952	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	234	75	0	2026-10-22 01:49:17.41+07	2026-10-22 01:49:17.4184+07
3953	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	238	75	0	2026-10-22 01:49:17.41+07	2026-10-22 01:49:17.421498+07
3954	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	242	75	0	2026-10-22 01:49:20.904+07	2026-10-22 01:49:20.912554+07
3955	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	238	75	0	2026-10-22 01:49:20.904+07	2026-10-22 01:49:20.915392+07
3956	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	235	75	0	2026-10-22 01:49:24.414+07	2026-10-22 01:49:24.42072+07
3957	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	238	75	0	2026-10-22 01:49:24.414+07	2026-10-22 01:49:24.425087+07
3958	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	230	75	0	2026-10-22 01:49:27.914+07	2026-10-22 01:49:27.924055+07
3959	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	238	75	0	2026-10-22 01:49:27.914+07	2026-10-22 01:49:27.929593+07
3960	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	235	75	0	2026-10-22 01:49:31.414+07	2026-10-22 01:49:31.418356+07
3961	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	239	75	0	2026-10-22 01:49:31.415+07	2026-10-22 01:49:31.419954+07
3962	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	233	75	0	2026-10-22 01:49:34.907+07	2026-10-22 01:49:34.917576+07
3963	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	239	75	0	2026-10-22 01:49:34.907+07	2026-10-22 01:49:34.919974+07
3964	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	227	75	0	2026-10-22 01:49:38.407+07	2026-10-22 01:49:38.413108+07
3965	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	238	75	0	2026-10-22 01:49:38.407+07	2026-10-22 01:49:38.416092+07
3966	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	236	75	0	2026-10-22 01:49:41.901+07	2026-10-22 01:49:41.905594+07
3967	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	240	75	0	2026-10-22 01:49:41.901+07	2026-10-22 01:49:41.908004+07
3968	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	219	75	0	2026-10-22 01:49:45.42+07	2026-10-22 01:49:45.42431+07
3969	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	224	75	0	2026-10-22 01:49:45.418+07	2026-10-22 01:49:45.425776+07
3970	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	237	75	0	2026-10-22 01:49:48.911+07	2026-10-22 01:49:48.915151+07
3971	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	240	75	0	2026-10-22 01:49:48.911+07	2026-10-22 01:49:48.916777+07
3972	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	238	75	0	2026-10-22 01:49:52.408+07	2026-10-22 01:49:52.411934+07
3973	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	230	75	0	2026-10-22 01:49:52.408+07	2026-10-22 01:49:52.413599+07
3974	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	222	75	0	2026-10-22 01:49:55.907+07	2026-10-22 01:49:55.91096+07
3975	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	229	75	0	2026-10-22 01:49:55.907+07	2026-10-22 01:49:55.912737+07
3976	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	230	75	0	2026-10-22 01:49:59.411+07	2026-10-22 01:49:59.417442+07
3977	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	237	75	0	2026-10-22 01:49:59.411+07	2026-10-22 01:49:59.419893+07
3978	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	216	75	0	2026-10-22 01:50:02.908+07	2026-10-22 01:50:02.913399+07
3979	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	230	75	0	2026-10-22 01:50:02.908+07	2026-10-22 01:50:02.916439+07
3980	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	234	75	0	2026-10-22 01:50:06.412+07	2026-10-22 01:50:06.418704+07
3981	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	238	75	0	2026-10-22 01:50:06.412+07	2026-10-22 01:50:06.420585+07
3982	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	260	75	0	2026-10-22 01:50:09.911+07	2026-10-22 01:50:09.921273+07
3983	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	39	0	7	2026-10-22 01:50:07.346+07	2026-10-22 01:50:09.925527+07
3984	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	240	75	0	2026-10-22 01:50:13.4+07	2026-10-22 01:50:13.403492+07
3985	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	43	0	10.33	2026-10-22 01:50:10.887+07	2026-10-22 01:50:13.405037+07
3986	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	42	0	9	2026-10-22 01:50:14.362+07	2026-10-22 01:50:16.906385+07
3987	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	238	75	0	2026-10-22 01:50:16.902+07	2026-10-22 01:50:16.908211+07
3988	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	237	75	0	2026-10-22 01:50:20.407+07	2026-10-22 01:50:20.412433+07
3989	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	226	75	0	2026-10-22 01:50:20.407+07	2026-10-22 01:50:20.415438+07
3990	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	222	75	0	2026-10-22 01:50:23.91+07	2026-10-22 01:50:23.921838+07
3991	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	217	75	0	2026-10-22 01:50:23.911+07	2026-10-22 01:50:23.924751+07
3992	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	239	75	0	2026-10-22 01:50:27.411+07	2026-10-22 01:50:27.414808+07
3993	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	235	75	0	2026-10-22 01:50:27.411+07	2026-10-22 01:50:27.416378+07
3994	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	239	75	0	2026-10-22 01:50:30.9+07	2026-10-22 01:50:30.903644+07
3995	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	232	75	0	2026-10-22 01:50:30.9+07	2026-10-22 01:50:30.905435+07
3998	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	229	75	0	2026-10-22 01:50:37.916+07	2026-10-22 01:50:37.920408+07
3999	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	235	75	0	2026-10-22 01:50:37.916+07	2026-10-22 01:50:37.921971+07
4010	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	40	0	8.33	2026-10-22 01:50:55.01+07	2026-10-22 01:50:55.021093+07
4011	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	41	0	10.67	2026-10-22 01:50:55.017+07	2026-10-22 01:50:55.022776+07
4016	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	236	75	0	2026-10-22 01:51:05.404+07	2026-10-22 01:51:05.408191+07
4929	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	243	75	0	2026-10-22 03:28:44.91+07	2026-10-22 03:28:44.917194+07
5062	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	241	75	0	2026-10-22 03:41:11.914+07	2026-10-22 03:41:11.930857+07
5063	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	235	75	0	2026-10-22 03:41:11.914+07	2026-10-22 03:41:11.93697+07
5064	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	252	75	0	2026-10-22 03:41:11.914+07	2026-10-22 03:41:11.942215+07
5065	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	228	75	0	2026-10-22 03:41:11.914+07	2026-10-22 03:41:11.94635+07
5066	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	246	75	0	2026-10-22 03:41:11.914+07	2026-10-22 03:41:11.951354+07
5087	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	735	75	0	2026-10-22 03:42:03.915+07	2026-10-22 03:42:03.920057+07
5088	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	731	75	0	2026-10-22 03:42:03.915+07	2026-10-22 03:42:03.921805+07
5089	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	744	75	0	2026-10-22 03:42:03.915+07	2026-10-22 03:42:03.923434+07
5090	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	739	75	0	2026-10-22 03:42:03.915+07	2026-10-22 03:42:03.925063+07
5091	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	726	75	0	2026-10-22 03:42:03.915+07	2026-10-22 03:42:03.927172+07
5092	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	715	75	0	2026-10-22 03:42:07.904+07	2026-10-22 03:42:07.908438+07
5093	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	710	75	0	2026-10-22 03:42:07.904+07	2026-10-22 03:42:07.910516+07
5094	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	729	75	0	2026-10-22 03:42:07.904+07	2026-10-22 03:42:07.912535+07
5095	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	723	75	0	2026-10-22 03:42:07.904+07	2026-10-22 03:42:07.914735+07
5096	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	719	75	0	2026-10-22 03:42:07.904+07	2026-10-22 03:42:07.917606+07
5097	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	721	75	0	2026-10-22 03:42:11.923+07	2026-10-22 03:42:11.92858+07
5098	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	727	75	0	2026-10-22 03:42:11.923+07	2026-10-22 03:42:11.930847+07
5099	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	734	75	0	2026-10-22 03:42:11.923+07	2026-10-22 03:42:11.9332+07
5100	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	741	75	0	2026-10-22 03:42:11.923+07	2026-10-22 03:42:11.935454+07
5101	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	750	75	0	2026-10-22 03:42:11.919+07	2026-10-22 03:42:11.937506+07
5102	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	722	75	0	2026-10-22 03:42:15.918+07	2026-10-22 03:42:15.922527+07
5103	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	727	75	0	2026-10-22 03:42:15.918+07	2026-10-22 03:42:15.924372+07
5104	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	730	75	0	2026-10-22 03:42:15.918+07	2026-10-22 03:42:15.926365+07
5105	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	742	75	0	2026-10-22 03:42:15.918+07	2026-10-22 03:42:15.928241+07
5106	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	718	75	0	2026-10-22 03:42:15.918+07	2026-10-22 03:42:15.930061+07
5107	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	718	75	0	2026-10-22 03:42:19.908+07	2026-10-22 03:42:19.912212+07
5108	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	722	75	0	2026-10-22 03:42:19.908+07	2026-10-22 03:42:19.913904+07
5109	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	726	75	0	2026-10-22 03:42:19.908+07	2026-10-22 03:42:19.915616+07
5110	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	733	75	0	2026-10-22 03:42:19.908+07	2026-10-22 03:42:19.917618+07
5111	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	713	75	0	2026-10-22 03:42:19.908+07	2026-10-22 03:42:19.919503+07
5112	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	729	75	0	2026-10-22 03:42:23.92+07	2026-10-22 03:42:23.926525+07
5113	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	740	75	0	2026-10-22 03:42:23.92+07	2026-10-22 03:42:23.928565+07
5114	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	225	75	0	2026-10-22 03:42:23.401+07	2026-10-22 03:42:23.930476+07
5115	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	216	75	0	2026-10-22 03:42:23.401+07	2026-10-22 03:42:23.932176+07
5116	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	221	75	0	2026-10-22 03:42:23.401+07	2026-10-22 03:42:23.934099+07
5117	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	225	75	0	2026-10-22 03:42:27.403+07	2026-10-22 03:42:27.407403+07
5118	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	202	75	0	2026-10-22 03:42:27.403+07	2026-10-22 03:42:27.409285+07
5119	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	218	75	0	2026-10-22 03:42:27.403+07	2026-10-22 03:42:27.411071+07
5120	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	192	75	0	2026-10-22 03:42:27.403+07	2026-10-22 03:42:27.412898+07
5121	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	211	75	0	2026-10-22 03:42:27.403+07	2026-10-22 03:42:27.414865+07
5122	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	225	75	0	2026-10-22 03:42:30.922+07	2026-10-22 03:42:30.930028+07
5123	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	233	75	0	2026-10-22 03:42:30.922+07	2026-10-22 03:42:30.932852+07
5124	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	229	75	0	2026-10-22 03:42:30.922+07	2026-10-22 03:42:30.935228+07
5125	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	237	75	0	2026-10-22 03:42:30.921+07	2026-10-22 03:42:30.938148+07
5126	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	220	75	0	2026-10-22 03:42:30.915+07	2026-10-22 03:42:30.940143+07
5318	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	216	75	0	2026-10-22 03:48:10.918+07	2026-10-22 03:48:10.935122+07
3996	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	231	75	0	2026-10-22 01:50:34.401+07	2026-10-22 01:50:34.404332+07
3997	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	239	75	0	2026-10-22 01:50:34.4+07	2026-10-22 01:50:34.406306+07
4006	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	237	75	0	2026-10-22 01:50:52.413+07	2026-10-22 01:50:52.917654+07
4007	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 01:50:52.914+07	2026-10-22 01:50:52.919401+07
4008	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	88	0	48	2026-10-22 01:50:54.047+07	2026-10-22 01:50:54.055652+07
4009	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	39	0	17.33	2026-10-22 01:50:53.868+07	2026-10-22 01:50:54.05957+07
4930	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	236	75	0	2026-10-22 03:30:07.408+07	2026-10-22 03:30:07.416769+07
5127	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	222	75	0	2026-10-22 03:42:34.409+07	2026-10-22 03:42:34.41604+07
5128	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	209	75	0	2026-10-22 03:42:34.411+07	2026-10-22 03:42:34.419342+07
5129	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	218	75	0	2026-10-22 03:42:34.408+07	2026-10-22 03:42:34.422768+07
5130	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	229	75	0	2026-10-22 03:42:34.409+07	2026-10-22 03:42:34.424438+07
5131	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	213	75	0	2026-10-22 03:42:34.408+07	2026-10-22 03:42:34.426049+07
5132	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	228	75	0	2026-10-22 03:42:37.915+07	2026-10-22 03:42:37.919524+07
5133	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	233	75	0	2026-10-22 03:42:37.915+07	2026-10-22 03:42:37.921328+07
5134	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	254	75	0	2026-10-22 03:42:37.915+07	2026-10-22 03:42:37.923331+07
5135	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	242	75	0	2026-10-22 03:42:37.915+07	2026-10-22 03:42:37.925259+07
5136	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	221	75	0	2026-10-22 03:42:37.915+07	2026-10-22 03:42:37.927094+07
5137	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	227	75	0	2026-10-22 03:42:41.413+07	2026-10-22 03:42:41.418422+07
5138	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	219	75	0	2026-10-22 03:42:41.413+07	2026-10-22 03:42:41.421055+07
5139	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	231	75	0	2026-10-22 03:42:41.413+07	2026-10-22 03:42:41.423624+07
5140	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	237	75	0	2026-10-22 03:42:41.412+07	2026-10-22 03:42:41.42608+07
5141	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	224	75	0	2026-10-22 03:42:41.412+07	2026-10-22 03:42:41.428248+07
5142	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	244	75	0	2026-10-22 03:42:44.91+07	2026-10-22 03:42:44.914848+07
5143	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	252	75	0	2026-10-22 03:42:44.91+07	2026-10-22 03:42:44.916754+07
5144	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	225	75	0	2026-10-22 03:42:44.91+07	2026-10-22 03:42:44.918828+07
5145	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	248	75	0	2026-10-22 03:42:44.91+07	2026-10-22 03:42:44.920698+07
5146	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	230	75	0	2026-10-22 03:42:44.91+07	2026-10-22 03:42:44.922945+07
5147	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	59	0	16	2026-10-22 03:42:45.965+07	2026-10-22 03:42:48.414258+07
5148	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	242	75	0	2026-10-22 03:42:48.41+07	2026-10-22 03:42:48.416994+07
5149	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	60	0	20	2026-10-22 03:42:45.958+07	2026-10-22 03:42:48.41877+07
5150	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	51	0	17.33	2026-10-22 03:42:45.965+07	2026-10-22 03:42:48.420645+07
5151	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	239	75	0	2026-10-22 03:42:48.41+07	2026-10-22 03:42:48.42225+07
5152	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	219	75	0	2026-10-22 03:42:51.918+07	2026-10-22 03:42:51.924522+07
5153	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	235	75	0	2026-10-22 03:42:51.918+07	2026-10-22 03:42:51.927368+07
5154	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	198	75	0	2026-10-22 03:42:51.918+07	2026-10-22 03:42:51.930209+07
5155	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	227	75	0	2026-10-22 03:42:51.918+07	2026-10-22 03:42:51.932747+07
5156	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	209	75	0	2026-10-22 03:42:51.918+07	2026-10-22 03:42:51.935105+07
5157	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	223	75	0	2026-10-22 03:42:55.414+07	2026-10-22 03:42:55.420126+07
5158	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	236	75	0	2026-10-22 03:42:55.414+07	2026-10-22 03:42:55.423469+07
5159	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	217	75	0	2026-10-22 03:42:55.414+07	2026-10-22 03:42:55.426242+07
5160	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	230	75	0	2026-10-22 03:42:55.414+07	2026-10-22 03:42:55.428467+07
5161	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	242	75	0	2026-10-22 03:42:55.414+07	2026-10-22 03:42:55.430456+07
5162	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	224	75	0	2026-10-22 03:42:58.917+07	2026-10-22 03:42:58.921504+07
5163	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	223	75	0	2026-10-22 03:42:58.917+07	2026-10-22 03:42:58.92325+07
5164	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	220	75	0	2026-10-22 03:42:58.917+07	2026-10-22 03:42:58.924886+07
5165	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	210	75	0	2026-10-22 03:42:58.917+07	2026-10-22 03:42:58.926682+07
5166	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	245	75	0	2026-10-22 03:42:58.917+07	2026-10-22 03:42:58.928557+07
5245	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	194	75	0	2026-10-22 03:45:54.917+07	2026-10-22 03:45:54.936926+07
5246	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	244	75	0	2026-10-22 03:45:54.921+07	2026-10-22 03:45:54.93993+07
5247	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	206	75	0	2026-10-22 03:45:54.917+07	2026-10-22 03:45:54.94353+07
5248	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	215	75	0	2026-10-22 03:45:58.406+07	2026-10-22 03:45:58.410914+07
5249	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	207	75	0	2026-10-22 03:45:58.406+07	2026-10-22 03:45:58.413301+07
5250	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	231	75	0	2026-10-22 03:45:58.406+07	2026-10-22 03:45:58.415676+07
5251	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	224	75	0	2026-10-22 03:45:58.406+07	2026-10-22 03:45:58.417897+07
5252	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	230	75	0	2026-10-22 03:45:58.406+07	2026-10-22 03:45:58.419837+07
5253	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	218	75	0	2026-10-22 03:46:01.909+07	2026-10-22 03:46:01.917488+07
5254	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	233	75	0	2026-10-22 03:46:01.909+07	2026-10-22 03:46:01.920648+07
5255	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	244	75	0	2026-10-22 03:46:01.909+07	2026-10-22 03:46:01.923402+07
4000	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	238	75	0	2026-10-22 01:50:41.407+07	2026-10-22 01:50:41.411912+07
4001	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	242	75	0	2026-10-22 01:50:41.407+07	2026-10-22 01:50:41.41394+07
4012	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	238	75	0	2026-10-22 01:50:58.406+07	2026-10-22 01:50:58.410704+07
4013	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	49	0	14.67	2026-10-22 01:50:55.992+07	2026-10-22 01:50:58.412458+07
4014	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	235	75	0	2026-10-22 01:51:01.909+07	2026-10-22 01:51:01.918689+07
4015	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	238	75	0	2026-10-22 01:51:01.909+07	2026-10-22 01:51:01.922441+07
4931	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-22 03:31:29.903+07	2026-10-22 03:31:29.910898+07
5167	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	239	75	0	2026-10-22 03:43:02.405+07	2026-10-22 03:43:02.909789+07
5168	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 03:43:02.904+07	2026-10-22 03:43:02.920291+07
5169	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	233	75	0	2026-10-22 03:43:02.405+07	2026-10-22 03:43:02.922059+07
5170	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	244	75	0	2026-10-22 03:43:02.405+07	2026-10-22 03:43:02.923767+07
5171	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 03:43:02.904+07	2026-10-22 03:43:02.925454+07
5172	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	80	0	41.67	2026-10-22 03:43:04.011+07	2026-10-22 03:43:06.415893+07
5173	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	56	0	28.33	2026-10-22 03:43:03.933+07	2026-10-22 03:43:06.417734+07
5174	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	55	0	23.33	2026-10-22 03:43:03.939+07	2026-10-22 03:43:06.419512+07
5175	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	51	0	18	2026-10-22 03:43:03.943+07	2026-10-22 03:43:06.421283+07
5176	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	237	75	0	2026-10-22 03:43:06.412+07	2026-10-22 03:43:06.423046+07
5177	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	40	0	11.67	2026-10-22 03:43:07.353+07	2026-10-22 03:43:09.918164+07
5178	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	222	75	0	2026-10-22 03:43:09.913+07	2026-10-22 03:43:09.919956+07
5179	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	241	75	0	2026-10-22 03:43:09.913+07	2026-10-22 03:43:09.921736+07
5180	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	250	75	0	2026-10-22 03:43:09.913+07	2026-10-22 03:43:09.92361+07
5181	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	230	75	0	2026-10-22 03:43:09.913+07	2026-10-22 03:43:09.925291+07
5256	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	226	75	0	2026-10-22 03:46:01.909+07	2026-10-22 03:46:01.926085+07
5257	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	239	75	0	2026-10-22 03:46:01.909+07	2026-10-22 03:46:01.929904+07
5258	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	227	75	0	2026-10-22 03:46:05.418+07	2026-10-22 03:46:05.422583+07
5259	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	215	75	0	2026-10-22 03:46:05.418+07	2026-10-22 03:46:05.424265+07
5260	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	227	75	0	2026-10-22 03:46:05.418+07	2026-10-22 03:46:05.425854+07
5261	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	245	75	0	2026-10-22 03:46:05.418+07	2026-10-22 03:46:05.427947+07
5262	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	236	75	0	2026-10-22 03:46:05.418+07	2026-10-22 03:46:05.43077+07
5263	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	225	75	0	2026-10-22 03:46:08.912+07	2026-10-22 03:46:08.927577+07
5264	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	216	75	0	2026-10-22 03:46:08.911+07	2026-10-22 03:46:08.933006+07
5265	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	198	75	0	2026-10-22 03:46:08.919+07	2026-10-22 03:46:08.93651+07
5266	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	233	75	0	2026-10-22 03:46:08.919+07	2026-10-22 03:46:08.939445+07
5267	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	207	75	0	2026-10-22 03:46:08.912+07	2026-10-22 03:46:08.942138+07
5305	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	216	75	0	2026-10-22 03:46:37.408+07	2026-10-22 03:46:37.417262+07
5306	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	224	75	0	2026-10-22 03:46:37.408+07	2026-10-22 03:46:37.419448+07
5307	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	235	75	0	2026-10-22 03:46:37.408+07	2026-10-22 03:46:37.421285+07
5308	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	216	75	0	2026-10-22 03:46:40.925+07	2026-10-22 03:46:40.934152+07
5309	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	204	75	0	2026-10-22 03:46:40.917+07	2026-10-22 03:46:40.937722+07
5310	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	240	75	0	2026-10-22 03:46:40.925+07	2026-10-22 03:46:40.940477+07
5311	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	229	75	0	2026-10-22 03:46:40.918+07	2026-10-22 03:46:40.943126+07
5312	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	251	75	0	2026-10-22 03:46:40.918+07	2026-10-22 03:46:40.946069+07
5313	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	222	75	0	2026-10-22 03:46:44.407+07	2026-10-22 03:46:44.41226+07
5314	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	210	75	0	2026-10-22 03:46:44.407+07	2026-10-22 03:46:44.414857+07
5315	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	232	75	0	2026-10-22 03:46:44.407+07	2026-10-22 03:46:44.416775+07
5316	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	182	75	0	2026-10-22 03:46:44.407+07	2026-10-22 03:46:44.418757+07
5317	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	196	75	0	2026-10-22 03:46:44.407+07	2026-10-22 03:46:44.420367+07
5319	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	231	75	0	2026-10-22 03:49:33.908+07	2026-10-22 03:49:33.914109+07
5320	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	229	75	0	2026-10-22 03:50:56.413+07	2026-10-22 03:50:56.422049+07
5321	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	226	75	0	2026-10-22 03:52:18.918+07	2026-10-22 03:52:18.93629+07
5322	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	197	75	0	2026-10-22 03:52:18.917+07	2026-10-22 03:52:18.963744+07
5323	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	210	75	0	2026-10-22 03:52:18.918+07	2026-10-22 03:52:18.966825+07
5324	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	240	75	0	2026-10-22 03:52:18.918+07	2026-10-22 03:52:18.970224+07
5325	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	254	75	0	2026-10-22 03:52:18.917+07	2026-10-22 03:52:18.97365+07
5326	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	222	75	0	2026-10-22 03:52:19.912+07	2026-10-22 03:52:19.934451+07
5327	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	246	75	0	2026-10-22 03:52:19.912+07	2026-10-22 03:52:19.941245+07
5328	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	217	75	0	2026-10-22 03:52:19.922+07	2026-10-22 03:52:19.945743+07
4002	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	237	75	0	2026-10-22 01:50:44.906+07	2026-10-22 01:50:44.90975+07
4003	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	225	75	0	2026-10-22 01:50:44.906+07	2026-10-22 01:50:44.911723+07
4004	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 01:50:48.911+07	2026-10-22 01:50:48.918782+07
4005	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	222	75	0	2026-10-22 01:50:48.405+07	2026-10-22 01:50:48.921761+07
4017	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	244	75	0	2026-10-22 01:59:23.917+07	2026-10-22 01:59:23.923813+07
4018	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	248	75	0	2026-10-22 01:59:23.917+07	2026-10-22 01:59:23.933736+07
4019	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	228	75	0	2026-10-22 01:59:24.405+07	2026-10-22 01:59:24.41156+07
4020	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	223	75	0	2026-10-22 01:59:24.405+07	2026-10-22 01:59:24.415539+07
4021	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	226	75	0	2026-10-22 01:59:27.911+07	2026-10-22 01:59:27.921842+07
4022	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	236	75	0	2026-10-22 01:59:27.911+07	2026-10-22 01:59:27.9251+07
4023	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	234	75	0	2026-10-22 01:59:31.41+07	2026-10-22 01:59:31.419898+07
4024	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	242	75	0	2026-10-22 01:59:31.411+07	2026-10-22 01:59:31.423041+07
4025	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	244	75	0	2026-10-22 01:59:34.911+07	2026-10-22 01:59:34.917661+07
4026	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	240	75	0	2026-10-22 01:59:34.911+07	2026-10-22 01:59:34.920038+07
4027	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	241	75	0	2026-10-22 01:59:38.409+07	2026-10-22 01:59:38.420893+07
4028	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	233	75	0	2026-10-22 01:59:38.409+07	2026-10-22 01:59:38.426561+07
4029	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	222	75	0	2026-10-22 01:59:41.899+07	2026-10-22 01:59:41.903487+07
4030	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	242	75	0	2026-10-22 01:59:41.899+07	2026-10-22 01:59:41.905132+07
4031	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	239	75	0	2026-10-22 01:59:45.412+07	2026-10-22 01:59:45.420666+07
4032	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	43	0	11.67	2026-10-22 01:59:42.868+07	2026-10-22 01:59:45.424791+07
4033	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	240	75	0	2026-10-22 01:59:48.918+07	2026-10-22 01:59:48.925529+07
4034	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	234	75	0	2026-10-22 01:59:48.919+07	2026-10-22 01:59:48.928499+07
4035	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	237	75	0	2026-10-22 01:59:52.41+07	2026-10-22 01:59:52.417417+07
4036	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	48	0	10	2026-10-22 01:59:49.895+07	2026-10-22 01:59:52.419453+07
4037	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	237	75	0	2026-10-22 01:59:55.919+07	2026-10-22 01:59:55.929056+07
4038	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	243	75	0	2026-10-22 01:59:55.919+07	2026-10-22 01:59:55.934314+07
4039	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	240	75	0	2026-10-22 01:59:59.413+07	2026-10-22 01:59:59.417471+07
4040	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	230	75	0	2026-10-22 01:59:59.413+07	2026-10-22 01:59:59.419985+07
4041	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	237	75	0	2026-10-22 02:00:02.908+07	2026-10-22 02:00:02.918496+07
4042	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	240	75	0	2026-10-22 02:00:02.908+07	2026-10-22 02:00:02.921271+07
4043	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	230	75	0	2026-10-22 02:00:06.416+07	2026-10-22 02:00:06.4211+07
4044	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	236	75	0	2026-10-22 02:00:06.416+07	2026-10-22 02:00:06.422969+07
4045	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	236	75	0	2026-10-22 02:00:09.904+07	2026-10-22 02:00:09.90882+07
4046	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	240	75	0	2026-10-22 02:00:09.904+07	2026-10-22 02:00:09.911177+07
4047	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	239	75	0	2026-10-22 02:00:13.415+07	2026-10-22 02:00:13.419609+07
4048	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	245	75	0	2026-10-22 02:00:13.415+07	2026-10-22 02:00:13.422003+07
4049	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	233	75	0	2026-10-22 02:00:16.908+07	2026-10-22 02:00:16.911902+07
4050	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	244	75	0	2026-10-22 02:00:16.908+07	2026-10-22 02:00:16.91371+07
4051	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	240	75	0	2026-10-22 02:00:20.4+07	2026-10-22 02:00:20.40421+07
4052	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	229	75	0	2026-10-22 02:00:20.4+07	2026-10-22 02:00:20.406033+07
4053	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	231	75	0	2026-10-22 02:00:23.908+07	2026-10-22 02:00:23.924046+07
4054	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	242	75	0	2026-10-22 02:00:23.908+07	2026-10-22 02:00:23.928492+07
4055	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	240	75	0	2026-10-22 02:00:27.419+07	2026-10-22 02:00:27.430464+07
4056	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	235	75	0	2026-10-22 02:00:27.419+07	2026-10-22 02:00:27.435936+07
4057	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	231	75	0	2026-10-22 02:00:30.915+07	2026-10-22 02:00:30.919505+07
4058	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	243	75	0	2026-10-22 02:00:30.915+07	2026-10-22 02:00:30.921547+07
4059	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	237	75	0	2026-10-22 02:00:34.413+07	2026-10-22 02:00:34.416811+07
4060	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	241	75	0	2026-10-22 02:00:34.413+07	2026-10-22 02:00:34.418689+07
4061	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	239	75	0	2026-10-22 02:00:37.912+07	2026-10-22 02:00:37.916272+07
4062	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	235	75	0	2026-10-22 02:00:37.912+07	2026-10-22 02:00:37.918164+07
4063	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	245	75	0	2026-10-22 02:00:41.411+07	2026-10-22 02:00:41.416413+07
4064	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	205	75	0	2026-10-22 02:00:41.411+07	2026-10-22 02:00:41.41822+07
4065	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	230	75	0	2026-10-22 02:00:44.913+07	2026-10-22 02:00:44.918916+07
4066	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	238	75	0	2026-10-22 02:00:44.913+07	2026-10-22 02:00:44.921572+07
4067	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	243	75	0	2026-10-22 02:00:48.411+07	2026-10-22 02:00:48.415998+07
4068	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	232	75	0	2026-10-22 02:00:48.411+07	2026-10-22 02:00:48.417979+07
4069	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	243	75	0	2026-10-22 02:00:51.916+07	2026-10-22 02:00:51.920014+07
4070	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	232	75	0	2026-10-22 02:00:51.916+07	2026-10-22 02:00:51.921695+07
4071	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	238	75	0	2026-10-22 02:00:55.406+07	2026-10-22 02:00:55.411978+07
4072	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	227	75	0	2026-10-22 02:00:55.406+07	2026-10-22 02:00:55.415688+07
4073	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	242	75	0	2026-10-22 02:00:58.908+07	2026-10-22 02:00:58.912699+07
4074	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	236	75	0	2026-10-22 02:00:58.908+07	2026-10-22 02:00:58.91443+07
4087	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	239	75	0	2026-10-22 02:01:23.407+07	2026-10-22 02:01:23.41216+07
4088	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	243	75	0	2026-10-22 02:01:23.407+07	2026-10-22 02:01:23.413923+07
4089	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	226	75	0	2026-10-22 02:01:26.907+07	2026-10-22 02:01:26.912064+07
4090	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	217	75	0	2026-10-22 02:01:26.907+07	2026-10-22 02:01:26.913808+07
4091	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	240	75	0	2026-10-22 02:01:30.415+07	2026-10-22 02:01:30.419816+07
4092	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	228	75	0	2026-10-22 02:01:30.415+07	2026-10-22 02:01:30.421694+07
4093	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	239	75	0	2026-10-22 02:01:33.909+07	2026-10-22 02:01:33.91392+07
4094	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	233	75	0	2026-10-22 02:01:33.909+07	2026-10-22 02:01:33.915566+07
4095	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	240	75	0	2026-10-22 02:01:37.415+07	2026-10-22 02:01:37.42087+07
4096	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	236	75	0	2026-10-22 02:01:37.415+07	2026-10-22 02:01:37.423436+07
4097	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	235	75	0	2026-10-22 02:01:40.911+07	2026-10-22 02:01:40.917406+07
4098	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	39	0	5.33	2026-10-22 02:01:38.354+07	2026-10-22 02:01:40.919958+07
4099	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	237	75	0	2026-10-22 02:01:44.414+07	2026-10-22 02:01:44.418682+07
4100	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	47	0	6.33	2026-10-22 02:01:41.905+07	2026-10-22 02:01:44.420512+07
4101	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	41	0	9.67	2026-10-22 02:01:45.379+07	2026-10-22 02:01:47.903277+07
4102	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	235	75	0	2026-10-22 02:01:47.898+07	2026-10-22 02:01:47.905048+07
4103	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	238	75	0	2026-10-22 02:01:51.415+07	2026-10-22 02:01:51.419492+07
4104	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	233	75	0	2026-10-22 02:01:51.415+07	2026-10-22 02:01:51.421282+07
4105	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	249	75	0	2026-10-22 02:01:54.907+07	2026-10-22 02:01:54.911884+07
4106	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	254	75	0	2026-10-22 02:01:54.907+07	2026-10-22 02:01:54.91384+07
4107	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	248	75	0	2026-10-22 02:01:58.412+07	2026-10-22 02:01:58.418426+07
4108	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	242	75	0	2026-10-22 02:01:58.412+07	2026-10-22 02:01:58.421835+07
4932	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-22 03:32:52.409+07	2026-10-22 03:32:52.416931+07
5182	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	219	75	0	2026-10-22 03:43:13.411+07	2026-10-22 03:43:13.417208+07
5183	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	239	75	0	2026-10-22 03:43:13.411+07	2026-10-22 03:43:13.419237+07
5184	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	233	75	0	2026-10-22 03:43:13.411+07	2026-10-22 03:43:13.421179+07
5185	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	228	75	0	2026-10-22 03:43:13.411+07	2026-10-22 03:43:13.4229+07
5186	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	224	75	0	2026-10-22 03:43:13.411+07	2026-10-22 03:43:13.424605+07
5187	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	253	75	0	2026-10-22 03:43:16.906+07	2026-10-22 03:43:16.912193+07
5188	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	237	75	0	2026-10-22 03:43:16.908+07	2026-10-22 03:43:16.913991+07
5189	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	230	75	0	2026-10-22 03:43:16.906+07	2026-10-22 03:43:16.915942+07
5190	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	225	75	0	2026-10-22 03:43:16.908+07	2026-10-22 03:43:16.917676+07
5191	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	244	75	0	2026-10-22 03:43:16.906+07	2026-10-22 03:43:16.91987+07
5268	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	196	75	0	2026-10-22 03:46:12.402+07	2026-10-22 03:46:12.410779+07
5269	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	233	75	0	2026-10-22 03:46:12.402+07	2026-10-22 03:46:12.413922+07
5270	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	220	75	0	2026-10-22 03:46:12.402+07	2026-10-22 03:46:12.415639+07
5271	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	208	75	0	2026-10-22 03:46:12.402+07	2026-10-22 03:46:12.417197+07
5272	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	182	75	0	2026-10-22 03:46:12.402+07	2026-10-22 03:46:12.41871+07
5273	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	74	0	47.33	2026-10-22 03:46:13.488+07	2026-10-22 03:46:15.929345+07
5274	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	238	75	0	2026-10-22 03:46:15.921+07	2026-10-22 03:46:15.933995+07
5275	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	65	0	35.33	2026-10-22 03:46:13.485+07	2026-10-22 03:46:15.938283+07
5276	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	61	0	32.33	2026-10-22 03:46:13.49+07	2026-10-22 03:46:15.941786+07
5277	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	242	75	0	2026-10-22 03:46:15.921+07	2026-10-22 03:46:15.946002+07
5278	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	257	75	0	2026-10-22 03:46:19.404+07	2026-10-22 03:46:19.409154+07
5279	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	245	75	0	2026-10-22 03:46:19.404+07	2026-10-22 03:46:19.411341+07
5280	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	267	75	0	2026-10-22 03:46:19.405+07	2026-10-22 03:46:19.413972+07
5281	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	231	75	0	2026-10-22 03:46:19.404+07	2026-10-22 03:46:19.416243+07
5282	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	216	75	0	2026-10-22 03:46:19.404+07	2026-10-22 03:46:19.41815+07
5283	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	243	75	0	2026-10-22 03:46:22.928+07	2026-10-22 03:46:22.936079+07
5284	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	219	75	0	2026-10-22 03:46:22.929+07	2026-10-22 03:46:22.938824+07
5285	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	247	75	0	2026-10-22 03:46:22.928+07	2026-10-22 03:46:22.941536+07
5286	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	239	75	0	2026-10-22 03:46:22.929+07	2026-10-22 03:46:22.944405+07
5287	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	214	75	0	2026-10-22 03:46:22.929+07	2026-10-22 03:46:22.947446+07
4075	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	216	75	0	2026-10-22 02:01:02.41+07	2026-10-22 02:01:02.414905+07
4076	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	239	75	0	2026-10-22 02:01:02.41+07	2026-10-22 02:01:02.416868+07
4077	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	234	75	0	2026-10-22 02:01:05.908+07	2026-10-22 02:01:05.913165+07
4078	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	223	75	0	2026-10-22 02:01:05.908+07	2026-10-22 02:01:05.914845+07
4079	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	229	75	0	2026-10-22 02:01:09.415+07	2026-10-22 02:01:09.41982+07
4080	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	240	75	0	2026-10-22 02:01:09.415+07	2026-10-22 02:01:09.421745+07
4081	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	242	75	0	2026-10-22 02:01:12.912+07	2026-10-22 02:01:12.919372+07
4082	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	235	75	0	2026-10-22 02:01:12.912+07	2026-10-22 02:01:12.924008+07
4083	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	235	75	0	2026-10-22 02:01:16.414+07	2026-10-22 02:01:16.41845+07
4084	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	241	75	0	2026-10-22 02:01:16.414+07	2026-10-22 02:01:16.42027+07
4085	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	226	75	0	2026-10-22 02:01:19.913+07	2026-10-22 02:01:19.917516+07
4086	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	239	75	0	2026-10-22 02:01:19.913+07	2026-10-22 02:01:19.919246+07
4109	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	230	75	0	2026-10-22 02:02:01.902+07	2026-10-22 02:02:01.908471+07
4110	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	206	75	0	2026-10-22 02:02:01.902+07	2026-10-22 02:02:01.920008+07
4111	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	235	75	0	2026-10-22 02:02:05.409+07	2026-10-22 02:02:05.417143+07
4112	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	240	75	0	2026-10-22 02:02:05.409+07	2026-10-22 02:02:05.421442+07
4113	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	218	75	0	2026-10-22 02:02:08.905+07	2026-10-22 02:02:08.909647+07
4114	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	221	75	0	2026-10-22 02:02:08.905+07	2026-10-22 02:02:08.911397+07
4115	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	238	75	0	2026-10-22 02:02:12.404+07	2026-10-22 02:02:12.408084+07
4116	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	227	75	0	2026-10-22 02:02:12.404+07	2026-10-22 02:02:12.409958+07
4117	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	214	75	0	2026-10-22 02:02:15.908+07	2026-10-22 02:02:15.912129+07
4118	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	225	75	0	2026-10-22 02:02:15.908+07	2026-10-22 02:02:15.913805+07
4119	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 02:02:19.908+07	2026-10-22 02:02:19.912066+07
4120	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	239	75	0	2026-10-22 02:02:19.407+07	2026-10-22 02:02:19.913993+07
4121	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	225	75	0	2026-10-22 02:02:23.412+07	2026-10-22 02:02:23.915675+07
4122	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 02:02:23.912+07	2026-10-22 02:02:23.917326+07
4123	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	135	0	23.67	2026-10-22 02:02:25.24+07	2026-10-22 02:02:25.250193+07
4124	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	49	0	6.67	2026-10-22 02:02:24.908+07	2026-10-22 02:02:25.255525+07
4125	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	38	0	2.33	2026-10-22 02:02:26.189+07	2026-10-22 02:02:26.225484+07
4126	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	41	0	7.67	2026-10-22 02:02:26.222+07	2026-10-22 02:02:26.227065+07
4127	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	241	75	0	2026-10-22 02:02:29.417+07	2026-10-22 02:02:29.420505+07
4128	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	39	0	9.67	2026-10-22 02:02:27.156+07	2026-10-22 02:02:29.422294+07
4129	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	233	75	0	2026-10-22 02:02:32.915+07	2026-10-22 02:02:32.918528+07
4130	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	241	75	0	2026-10-22 02:02:32.915+07	2026-10-22 02:02:32.920176+07
4131	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	225	75	0	2026-10-22 02:02:36.413+07	2026-10-22 02:02:36.422637+07
4132	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	241	75	0	2026-10-22 02:42:28.907+07	2026-10-22 02:42:28.92591+07
4133	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	238	75	0	2026-10-22 02:42:28.907+07	2026-10-22 02:42:28.931873+07
4134	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	252	75	0	2026-10-22 02:42:31.907+07	2026-10-22 02:42:31.914817+07
4135	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	255	75	0	2026-10-22 02:42:31.907+07	2026-10-22 02:42:31.92051+07
4136	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	235	75	0	2026-10-22 02:42:35.409+07	2026-10-22 02:42:35.424476+07
4137	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	242	75	0	2026-10-22 02:42:35.409+07	2026-10-22 02:42:35.430034+07
4138	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	243	75	0	2026-10-22 02:42:38.909+07	2026-10-22 02:42:38.915129+07
4139	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	237	75	0	2026-10-22 02:42:38.909+07	2026-10-22 02:42:38.917743+07
4140	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	226	75	0	2026-10-22 02:42:42.411+07	2026-10-22 02:42:42.416347+07
4141	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	236	75	0	2026-10-22 02:42:42.411+07	2026-10-22 02:42:42.419458+07
4142	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	224	75	0	2026-10-22 02:42:45.908+07	2026-10-22 02:42:45.912202+07
4143	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	241	75	0	2026-10-22 02:42:45.908+07	2026-10-22 02:42:45.913936+07
4144	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	209	75	0	2026-10-22 02:42:49.408+07	2026-10-22 02:42:49.416419+07
4145	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	239	75	0	2026-10-22 02:42:49.408+07	2026-10-22 02:42:49.421101+07
4146	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	241	75	0	2026-10-22 02:42:52.899+07	2026-10-22 02:42:52.904549+07
4147	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	75	0	15.33	2026-10-22 02:42:50.508+07	2026-10-22 02:42:52.906467+07
4148	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	233	75	0	2026-10-22 02:42:56.407+07	2026-10-22 02:42:56.417544+07
4149	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	244	75	0	2026-10-22 02:42:56.407+07	2026-10-22 02:42:56.423113+07
4150	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	238	75	0	2026-10-22 02:42:59.905+07	2026-10-22 02:42:59.910417+07
4151	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	57	0	17.67	2026-10-22 02:42:57.443+07	2026-10-22 02:42:59.912986+07
4152	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	233	75	0	2026-10-22 02:43:03.41+07	2026-10-22 02:43:03.416887+07
4153	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	240	75	0	2026-10-22 02:43:03.41+07	2026-10-22 02:43:03.420606+07
4154	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	237	75	0	2026-10-22 02:43:06.903+07	2026-10-22 02:43:06.909866+07
4155	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	242	75	0	2026-10-22 02:43:06.903+07	2026-10-22 02:43:06.912922+07
4156	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	243	75	0	2026-10-22 02:43:10.41+07	2026-10-22 02:43:10.421097+07
4157	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	234	75	0	2026-10-22 02:43:10.41+07	2026-10-22 02:43:10.426808+07
4158	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	229	75	0	2026-10-22 02:43:13.906+07	2026-10-22 02:43:13.910489+07
4159	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	240	75	0	2026-10-22 02:43:13.906+07	2026-10-22 02:43:13.912111+07
4160	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	237	75	0	2026-10-22 02:43:17.405+07	2026-10-22 02:43:17.410285+07
4161	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	227	75	0	2026-10-22 02:43:17.405+07	2026-10-22 02:43:17.412235+07
4162	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	238	75	0	2026-10-22 02:43:20.907+07	2026-10-22 02:43:20.91207+07
4163	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	244	75	0	2026-10-22 02:43:20.907+07	2026-10-22 02:43:20.914121+07
4164	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	243	75	0	2026-10-22 02:43:24.411+07	2026-10-22 02:43:24.421212+07
4165	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	235	75	0	2026-10-22 02:43:24.41+07	2026-10-22 02:43:24.427242+07
4166	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	243	75	0	2026-10-22 02:43:27.913+07	2026-10-22 02:43:27.91839+07
4167	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	232	75	0	2026-10-22 02:43:27.913+07	2026-10-22 02:43:27.920855+07
4174	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	247	75	0	2026-10-22 02:43:41.913+07	2026-10-22 02:43:41.924264+07
4175	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	236	75	0	2026-10-22 02:43:41.913+07	2026-10-22 02:43:41.929165+07
4176	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	234	75	0	2026-10-22 02:43:45.412+07	2026-10-22 02:43:45.426534+07
4177	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	242	75	0	2026-10-22 02:43:45.411+07	2026-10-22 02:43:45.431904+07
4178	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	223	75	0	2026-10-22 02:43:48.902+07	2026-10-22 02:43:48.906909+07
4179	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	227	75	0	2026-10-22 02:43:48.902+07	2026-10-22 02:43:48.908611+07
4180	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	244	75	0	2026-10-22 02:43:52.412+07	2026-10-22 02:43:52.418885+07
4181	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	233	75	0	2026-10-22 02:43:52.412+07	2026-10-22 02:43:52.422475+07
4186	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	243	75	0	2026-10-22 02:44:02.913+07	2026-10-22 02:44:02.920326+07
4187	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	248	75	0	2026-10-22 02:44:02.912+07	2026-10-22 02:44:02.923422+07
4188	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	235	75	0	2026-10-22 02:44:06.414+07	2026-10-22 02:44:06.42281+07
4189	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	242	75	0	2026-10-22 02:44:06.414+07	2026-10-22 02:44:06.427145+07
4190	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	244	75	0	2026-10-22 02:44:09.903+07	2026-10-22 02:44:09.907814+07
4191	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	234	75	0	2026-10-22 02:44:09.903+07	2026-10-22 02:44:09.909995+07
4192	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	235	75	0	2026-10-22 02:44:13.409+07	2026-10-22 02:44:13.415056+07
4193	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	243	75	0	2026-10-22 02:44:13.409+07	2026-10-22 02:44:13.419092+07
4198	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	225	75	0	2026-10-22 02:44:23.906+07	2026-10-22 02:44:23.912038+07
4199	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	236	75	0	2026-10-22 02:44:23.906+07	2026-10-22 02:44:23.914613+07
4202	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	236	75	0	2026-10-22 02:44:30.914+07	2026-10-22 02:44:30.919468+07
4203	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	241	75	0	2026-10-22 02:44:30.914+07	2026-10-22 02:44:30.92156+07
4204	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	233	75	0	2026-10-22 02:44:34.414+07	2026-10-22 02:44:34.421957+07
4205	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	241	75	0	2026-10-22 02:44:34.414+07	2026-10-22 02:44:34.425627+07
4214	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	241	75	0	2026-10-22 02:44:51.914+07	2026-10-22 02:44:51.92041+07
4215	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	45	0	14	2026-10-22 02:44:49.398+07	2026-10-22 02:44:51.92319+07
4216	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	41	0	11	2026-10-22 02:44:52.866+07	2026-10-22 02:44:55.41679+07
4217	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	242	75	0	2026-10-22 02:44:55.409+07	2026-10-22 02:44:55.420752+07
4933	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	236	75	0	2026-10-22 03:34:14.912+07	2026-10-22 03:34:14.923929+07
5192	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	235	75	0	2026-10-22 03:44:42.909+07	2026-10-22 03:44:42.916291+07
5288	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	230	75	0	2026-10-22 03:46:26.417+07	2026-10-22 03:46:26.421495+07
5289	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	241	75	0	2026-10-22 03:46:26.417+07	2026-10-22 03:46:26.423524+07
5290	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	191	75	0	2026-10-22 03:46:26.417+07	2026-10-22 03:46:26.425476+07
5291	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	206	75	0	2026-10-22 03:46:26.417+07	2026-10-22 03:46:26.427696+07
5292	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	219	75	0	2026-10-22 03:46:26.417+07	2026-10-22 03:46:26.430281+07
5293	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	222	75	0	2026-10-22 03:46:29.911+07	2026-10-22 03:46:30.409276+07
5294	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 03:46:30.405+07	2026-10-22 03:46:30.411341+07
5295	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	243	75	0	2026-10-22 03:46:29.911+07	2026-10-22 03:46:30.413794+07
5296	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	209	75	0	2026-10-22 03:46:29.911+07	2026-10-22 03:46:30.415826+07
5297	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 03:46:30.405+07	2026-10-22 03:46:30.417629+07
5298	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	124	0	50.67	2026-10-22 03:46:31.687+07	2026-10-22 03:46:33.921723+07
5299	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	60	0	28	2026-10-22 03:46:31.443+07	2026-10-22 03:46:33.925345+07
5300	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	57	0	22	2026-10-22 03:46:31.449+07	2026-10-22 03:46:33.92898+07
5301	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	53	0	18	2026-10-22 03:46:31.451+07	2026-10-22 03:46:33.932103+07
5302	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	239	75	0	2026-10-22 03:46:33.914+07	2026-10-22 03:46:33.934386+07
5303	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	71	0	14.33	2026-10-22 03:46:34.995+07	2026-10-22 03:46:37.413241+07
5304	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	202	75	0	2026-10-22 03:46:37.408+07	2026-10-22 03:46:37.415408+07
4168	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	259	75	0	2026-10-22 02:43:31.405+07	2026-10-22 02:43:31.415657+07
4169	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	248	75	0	2026-10-22 02:43:31.405+07	2026-10-22 02:43:31.420487+07
4170	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	246	75	0	2026-10-22 02:43:34.905+07	2026-10-22 02:43:34.910079+07
4171	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	235	75	0	2026-10-22 02:43:34.905+07	2026-10-22 02:43:34.911804+07
4172	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	238	75	0	2026-10-22 02:43:38.415+07	2026-10-22 02:43:38.424037+07
4173	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	235	75	0	2026-10-22 02:43:38.415+07	2026-10-22 02:43:38.428704+07
4182	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	233	75	0	2026-10-22 02:43:55.904+07	2026-10-22 02:43:55.91268+07
4183	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	245	75	0	2026-10-22 02:43:55.905+07	2026-10-22 02:43:55.916126+07
4184	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	239	75	0	2026-10-22 02:43:59.408+07	2026-10-22 02:43:59.414327+07
4185	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	230	75	0	2026-10-22 02:43:59.407+07	2026-10-22 02:43:59.417898+07
4194	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	242	75	0	2026-10-22 02:44:16.913+07	2026-10-22 02:44:16.918426+07
4195	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	234	75	0	2026-10-22 02:44:16.912+07	2026-10-22 02:44:16.920728+07
4196	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	239	75	0	2026-10-22 02:44:20.407+07	2026-10-22 02:44:20.413633+07
4197	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	231	75	0	2026-10-22 02:44:20.407+07	2026-10-22 02:44:20.416994+07
4200	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	233	75	0	2026-10-22 02:44:27.406+07	2026-10-22 02:44:27.411929+07
4201	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	238	75	0	2026-10-22 02:44:27.407+07	2026-10-22 02:44:27.414042+07
4206	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	239	75	0	2026-10-22 02:44:37.916+07	2026-10-22 02:44:37.922165+07
4207	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	249	75	0	2026-10-22 02:44:37.916+07	2026-10-22 02:44:37.925055+07
4208	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	242	75	0	2026-10-22 02:44:41.413+07	2026-10-22 02:44:41.417357+07
4209	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	231	75	0	2026-10-22 02:44:41.413+07	2026-10-22 02:44:41.419549+07
4210	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	232	75	0	2026-10-22 02:44:44.903+07	2026-10-22 02:44:44.907227+07
4211	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	239	75	0	2026-10-22 02:44:44.903+07	2026-10-22 02:44:44.908977+07
4212	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	239	75	0	2026-10-22 02:44:48.412+07	2026-10-22 02:44:48.420006+07
4213	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	37	0	9	2026-10-22 02:44:45.84+07	2026-10-22 02:44:48.424535+07
4218	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	246	75	0	2026-10-22 02:44:58.914+07	2026-10-22 02:44:58.920478+07
4219	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	243	75	0	2026-10-22 02:44:58.914+07	2026-10-22 02:44:58.92239+07
4220	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	238	75	0	2026-10-22 02:45:02.409+07	2026-10-22 02:45:02.418231+07
4221	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	227	75	0	2026-10-22 02:45:02.409+07	2026-10-22 02:45:02.421209+07
4222	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	240	75	0	2026-10-22 02:45:05.906+07	2026-10-22 02:45:05.911633+07
4223	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	227	75	0	2026-10-22 02:45:05.906+07	2026-10-22 02:45:05.914762+07
4224	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	234	75	0	2026-10-22 02:45:09.413+07	2026-10-22 02:45:09.419736+07
4225	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	240	75	0	2026-10-22 02:45:09.412+07	2026-10-22 02:45:09.424036+07
4226	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	234	75	0	2026-10-22 02:45:12.903+07	2026-10-22 02:45:12.906892+07
4227	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	238	75	0	2026-10-22 02:45:12.903+07	2026-10-22 02:45:12.908592+07
4228	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	242	75	0	2026-10-22 02:45:16.419+07	2026-10-22 02:45:16.427345+07
4229	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	230	75	0	2026-10-22 02:45:16.419+07	2026-10-22 02:45:16.430183+07
4230	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	241	75	0	2026-10-22 02:45:19.914+07	2026-10-22 02:45:19.92106+07
4231	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	233	75	0	2026-10-22 02:45:19.914+07	2026-10-22 02:45:19.923689+07
4232	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	242	75	0	2026-10-22 02:45:23.415+07	2026-10-22 02:45:23.422317+07
4233	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	230	75	0	2026-10-22 02:45:23.416+07	2026-10-22 02:45:23.425258+07
4234	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 02:45:27.413+07	2026-10-22 02:45:27.424394+07
4235	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	237	75	0	2026-10-22 02:45:26.913+07	2026-10-22 02:45:27.427239+07
4236	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	227	75	0	2026-10-22 02:45:30.914+07	2026-10-22 02:45:31.417853+07
4237	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 02:45:31.413+07	2026-10-22 02:45:31.420264+07
4238	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	114	0	51	2026-10-22 02:45:32.652+07	2026-10-22 02:45:32.655534+07
4239	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	36	0	7	2026-10-22 02:45:32.336+07	2026-10-22 02:45:32.657094+07
4240	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	43	0	5	2026-10-22 02:45:33.604+07	2026-10-22 02:45:33.617738+07
4241	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	45	0	10.33	2026-10-22 02:45:33.613+07	2026-10-22 02:45:33.619314+07
4242	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	254	75	0	2026-10-22 02:45:36.908+07	2026-10-22 02:45:36.913846+07
4243	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	62	0	14.33	2026-10-22 02:45:34.654+07	2026-10-22 02:45:36.916677+07
4244	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	236	75	0	2026-10-22 02:45:40.418+07	2026-10-22 02:45:40.424907+07
4245	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	243	75	0	2026-10-22 02:45:40.418+07	2026-10-22 02:45:40.428505+07
4246	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	238	75	0	2026-10-22 02:45:43.91+07	2026-10-22 02:45:43.914751+07
4247	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	240	75	0	2026-10-22 03:00:32.416+07	2026-10-22 03:00:32.426285+07
4248	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	230	75	0	2026-10-22 03:00:32.417+07	2026-10-22 03:00:32.4302+07
4249	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-22 03:00:34.915+07	2026-10-22 03:00:34.919497+07
4250	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	233	75	0	2026-10-22 03:00:34.915+07	2026-10-22 03:00:34.921137+07
4251	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	238	75	0	2026-10-22 03:00:38.405+07	2026-10-22 03:00:38.415575+07
4252	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	244	75	0	2026-10-22 03:00:38.405+07	2026-10-22 03:00:38.418273+07
4253	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	235	75	0	2026-10-22 03:00:41.914+07	2026-10-22 03:00:41.920061+07
4254	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	239	75	0	2026-10-22 03:00:41.914+07	2026-10-22 03:00:41.921924+07
4255	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	229	75	0	2026-10-22 03:00:45.411+07	2026-10-22 03:00:45.417295+07
4256	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	235	75	0	2026-10-22 03:00:45.411+07	2026-10-22 03:00:45.419642+07
4257	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	233	75	0	2026-10-22 03:00:48.91+07	2026-10-22 03:00:48.916709+07
4258	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	236	75	0	2026-10-22 03:00:48.91+07	2026-10-22 03:00:48.918547+07
4259	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	232	75	0	2026-10-22 03:00:52.408+07	2026-10-22 03:00:52.417993+07
4260	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	236	75	0	2026-10-22 03:00:52.408+07	2026-10-22 03:00:52.422167+07
4261	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	241	75	0	2026-10-22 03:00:55.909+07	2026-10-22 03:00:55.914163+07
4262	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	237	75	0	2026-10-22 03:00:55.909+07	2026-10-22 03:00:55.915939+07
4263	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	51	0	13.67	2026-10-22 03:00:56.897+07	2026-10-22 03:00:59.408311+07
4264	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	242	75	0	2026-10-22 03:00:59.403+07	2026-10-22 03:00:59.41073+07
4285	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	747	75	0	2026-10-22 03:01:42.414+07	2026-10-22 03:01:42.417791+07
4286	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	738	75	0	2026-10-22 03:01:42.414+07	2026-10-22 03:01:42.419575+07
4287	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	733	75	0	2026-10-22 03:01:46.408+07	2026-10-22 03:01:46.412836+07
4288	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	723	75	0	2026-10-22 03:01:46.408+07	2026-10-22 03:01:46.414727+07
4291	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	61	0	29	2026-10-22 03:01:51.44+07	2026-10-22 03:01:54.415804+07
4292	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	737	75	0	2026-10-22 03:01:54.412+07	2026-10-22 03:01:54.417509+07
4293	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	739	75	0	2026-10-22 03:01:58.412+07	2026-10-22 03:01:58.416447+07
4294	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	731	75	0	2026-10-22 03:01:58.412+07	2026-10-22 03:01:58.418167+07
4295	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	45	0	21	2026-10-22 03:01:59.392+07	2026-10-22 03:02:02.411317+07
4296	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	737	75	0	2026-10-22 03:02:02.407+07	2026-10-22 03:02:02.41299+07
4297	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	734	75	0	2026-10-22 03:02:06.403+07	2026-10-22 03:02:06.407438+07
4298	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	739	75	0	2026-10-22 03:02:06.403+07	2026-10-22 03:02:06.409197+07
4299	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	726	75	0	2026-10-22 03:02:10.405+07	2026-10-22 03:02:10.410756+07
4300	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	734	75	0	2026-10-22 03:02:10.405+07	2026-10-22 03:02:10.412705+07
4301	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	728	75	0	2026-10-22 03:02:14.403+07	2026-10-22 03:02:14.408104+07
4302	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	722	75	0	2026-10-22 03:02:14.403+07	2026-10-22 03:02:14.410941+07
4303	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	738	75	0	2026-10-22 03:02:18.403+07	2026-10-22 03:02:18.408231+07
4304	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	733	75	0	2026-10-22 03:02:18.403+07	2026-10-22 03:02:18.410789+07
4305	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	234	75	0	2026-10-22 03:02:21.904+07	2026-10-22 03:02:21.909706+07
4306	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	245	75	0	2026-10-22 03:02:21.904+07	2026-10-22 03:02:21.91248+07
4307	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	237	75	0	2026-10-22 03:02:25.408+07	2026-10-22 03:02:25.413943+07
4308	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	231	75	0	2026-10-22 03:02:25.408+07	2026-10-22 03:02:25.416524+07
4309	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	233	75	0	2026-10-22 03:02:28.914+07	2026-10-22 03:02:28.919361+07
4310	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	241	75	0	2026-10-22 03:02:28.914+07	2026-10-22 03:02:28.921298+07
4311	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	232	75	0	2026-10-22 03:02:32.407+07	2026-10-22 03:02:32.411772+07
4312	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	239	75	0	2026-10-22 03:02:32.407+07	2026-10-22 03:02:32.41358+07
4313	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	238	75	0	2026-10-22 03:02:35.914+07	2026-10-22 03:02:35.91883+07
4314	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	235	75	0	2026-10-22 03:02:35.914+07	2026-10-22 03:02:35.920544+07
4315	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	237	75	0	2026-10-22 03:02:39.413+07	2026-10-22 03:02:39.420484+07
4316	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	232	75	0	2026-10-22 03:02:39.414+07	2026-10-22 03:02:39.423819+07
4317	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	219	75	0	2026-10-22 03:02:42.908+07	2026-10-22 03:02:42.913606+07
4318	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	222	75	0	2026-10-22 03:02:42.908+07	2026-10-22 03:02:42.915729+07
4325	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	236	75	0	2026-10-22 03:02:56.901+07	2026-10-22 03:02:56.906225+07
4326	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	229	75	0	2026-10-22 03:02:56.901+07	2026-10-22 03:02:56.909492+07
4327	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	234	75	0	2026-10-22 03:03:00.401+07	2026-10-22 03:03:00.407277+07
4328	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	238	75	0	2026-10-22 03:03:00.401+07	2026-10-22 03:03:00.41015+07
4329	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	229	75	0	2026-10-22 03:03:03.914+07	2026-10-22 03:03:03.920562+07
4330	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	241	75	0	2026-10-22 03:03:03.914+07	2026-10-22 03:03:03.923155+07
4331	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	233	75	0	2026-10-22 03:03:07.407+07	2026-10-22 03:03:07.413863+07
4332	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	237	75	0	2026-10-22 03:03:07.407+07	2026-10-22 03:03:07.416848+07
4341	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	233	75	0	2026-10-22 03:03:24.906+07	2026-10-22 03:03:24.911646+07
4342	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	239	75	0	2026-10-22 03:03:24.906+07	2026-10-22 03:03:24.913557+07
4343	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	239	75	0	2026-10-22 03:03:28.401+07	2026-10-22 03:03:28.405712+07
4344	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	234	75	0	2026-10-22 03:03:28.401+07	2026-10-22 03:03:28.408196+07
4345	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	235	75	0	2026-10-22 03:03:31.909+07	2026-10-22 03:03:31.914875+07
4265	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	237	75	0	2026-10-22 03:01:02.9+07	2026-10-22 03:01:02.905426+07
4266	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	232	75	0	2026-10-22 03:01:02.9+07	2026-10-22 03:01:02.907193+07
4267	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	41	0	6.33	2026-10-22 03:01:03.852+07	2026-10-22 03:01:06.416032+07
4268	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	237	75	0	2026-10-22 03:01:06.41+07	2026-10-22 03:01:06.418574+07
4269	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	240	75	0	2026-10-22 03:01:09.9+07	2026-10-22 03:01:09.904745+07
4270	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	218	75	0	2026-10-22 03:01:09.9+07	2026-10-22 03:01:09.906668+07
4271	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	230	75	0	2026-10-22 03:01:13.411+07	2026-10-22 03:01:13.416566+07
4272	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	242	75	0	2026-10-22 03:01:13.411+07	2026-10-22 03:01:13.42077+07
4273	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	231	75	0	2026-10-22 03:01:16.902+07	2026-10-22 03:01:16.906298+07
4274	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	243	75	0	2026-10-22 03:01:16.901+07	2026-10-22 03:01:16.908535+07
4275	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	238	75	0	2026-10-22 03:01:20.405+07	2026-10-22 03:01:20.409472+07
4276	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	235	75	0	2026-10-22 03:01:20.405+07	2026-10-22 03:01:20.411341+07
4277	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	745	75	0	2026-10-22 03:01:26.41+07	2026-10-22 03:01:26.414753+07
4278	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	741	75	0	2026-10-22 03:01:26.41+07	2026-10-22 03:01:26.416346+07
4279	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	723	75	0	2026-10-22 03:01:30.403+07	2026-10-22 03:01:30.406728+07
4280	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	736	75	0	2026-10-22 03:01:30.403+07	2026-10-22 03:01:30.408716+07
4281	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	747	75	0	2026-10-22 03:01:34.401+07	2026-10-22 03:01:34.405864+07
4282	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	742	75	0	2026-10-22 03:01:34.401+07	2026-10-22 03:01:34.408291+07
4283	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	738	75	0	2026-10-22 03:01:38.403+07	2026-10-22 03:01:38.406836+07
4284	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	733	75	0	2026-10-22 03:01:38.403+07	2026-10-22 03:01:38.408748+07
4289	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	733	75	0	2026-10-22 03:01:50.408+07	2026-10-22 03:01:50.412268+07
4290	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	740	75	0	2026-10-22 03:01:50.408+07	2026-10-22 03:01:50.413989+07
4319	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	249	75	0	2026-10-22 03:02:46.413+07	2026-10-22 03:02:46.417214+07
4320	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	257	75	0	2026-10-22 03:02:46.412+07	2026-10-22 03:02:46.41881+07
4321	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	236	75	0	2026-10-22 03:02:49.911+07	2026-10-22 03:02:49.917196+07
4322	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	240	75	0	2026-10-22 03:02:49.911+07	2026-10-22 03:02:49.919089+07
4323	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	238	75	0	2026-10-22 03:02:53.414+07	2026-10-22 03:02:53.420317+07
4324	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	232	75	0	2026-10-22 03:02:53.414+07	2026-10-22 03:02:53.423153+07
4333	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	232	75	0	2026-10-22 03:03:10.904+07	2026-10-22 03:03:10.910826+07
4334	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	237	75	0	2026-10-22 03:03:10.904+07	2026-10-22 03:03:10.912878+07
4335	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	239	75	0	2026-10-22 03:03:14.407+07	2026-10-22 03:03:14.41224+07
4336	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	245	75	0	2026-10-22 03:03:14.407+07	2026-10-22 03:03:14.414158+07
4337	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	237	75	0	2026-10-22 03:03:17.905+07	2026-10-22 03:03:17.911131+07
4338	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	244	75	0	2026-10-22 03:03:17.905+07	2026-10-22 03:03:17.913147+07
4339	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	236	75	0	2026-10-22 03:03:21.402+07	2026-10-22 03:03:21.40912+07
4340	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	232	75	0	2026-10-22 03:03:21.403+07	2026-10-22 03:03:21.412505+07
4349	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	235	75	0	2026-10-22 03:03:38.914+07	2026-10-22 03:03:38.919226+07
4350	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	242	75	0	2026-10-22 03:03:38.914+07	2026-10-22 03:03:38.921176+07
4381	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 03:04:33.406+07	2026-10-22 03:04:33.411507+07
4382	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	128	0	34	2026-10-22 03:04:30.714+07	2026-10-22 03:04:33.413654+07
4383	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	39	0	6.33	2026-10-22 03:04:34.36+07	2026-10-22 03:04:34.368547+07
4384	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	39	0	4	2026-10-22 03:04:34.363+07	2026-10-22 03:04:34.371208+07
4391	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	254	75	0	2026-10-22 03:04:48.413+07	2026-10-22 03:04:48.416858+07
4392	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	249	75	0	2026-10-22 03:04:48.413+07	2026-10-22 03:04:48.418498+07
4934	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	247	75	0	2026-10-22 03:35:37.416+07	2026-10-22 03:35:37.422974+07
4936	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	225	75	0	2026-10-22 03:38:23.91+07	2026-10-22 03:38:23.914807+07
5193	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	716	75	0	2026-10-22 03:45:15.928+07	2026-10-22 03:45:15.945872+07
5194	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	744	75	0	2026-10-22 03:45:15.927+07	2026-10-22 03:45:15.952025+07
5195	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	732	75	0	2026-10-22 03:45:15.928+07	2026-10-22 03:45:15.956619+07
5196	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	722	75	0	2026-10-22 03:45:15.928+07	2026-10-22 03:45:15.960892+07
5197	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	754	75	0	2026-10-22 03:45:15.928+07	2026-10-22 03:45:15.965319+07
5198	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	203	75	0	2026-10-22 03:45:19.41+07	2026-10-22 03:45:19.415432+07
5199	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	164	75	0	2026-10-22 03:45:19.41+07	2026-10-22 03:45:19.417396+07
5200	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	215	75	0	2026-10-22 03:45:19.41+07	2026-10-22 03:45:19.419172+07
5201	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	191	75	0	2026-10-22 03:45:19.41+07	2026-10-22 03:45:19.42101+07
5202	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	178	75	0	2026-10-22 03:45:19.41+07	2026-10-22 03:45:19.422952+07
5203	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	729	75	0	2026-10-22 03:45:23.401+07	2026-10-22 03:45:23.405974+07
5204	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	737	75	0	2026-10-22 03:45:23.401+07	2026-10-22 03:45:23.407808+07
4346	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	246	75	0	2026-10-22 03:03:31.909+07	2026-10-22 03:03:31.917333+07
4347	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	231	75	0	2026-10-22 03:03:35.421+07	2026-10-22 03:03:35.42726+07
4348	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	240	75	0	2026-10-22 03:03:35.421+07	2026-10-22 03:03:35.430374+07
4351	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	227	75	0	2026-10-22 03:03:42.406+07	2026-10-22 03:03:42.410446+07
4352	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	217	75	0	2026-10-22 03:03:42.406+07	2026-10-22 03:03:42.412097+07
4353	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	232	75	0	2026-10-22 03:03:45.912+07	2026-10-22 03:03:45.915923+07
4354	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	244	75	0	2026-10-22 03:03:45.912+07	2026-10-22 03:03:45.917551+07
4355	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	235	75	0	2026-10-22 03:03:49.401+07	2026-10-22 03:03:49.40849+07
4356	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	230	75	0	2026-10-22 03:03:49.401+07	2026-10-22 03:03:49.41153+07
4357	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	56	0	36.33	2026-10-22 03:03:50.419+07	2026-10-22 03:03:52.914013+07
4358	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	244	75	0	2026-10-22 03:03:52.909+07	2026-10-22 03:03:52.915896+07
4359	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	59	0	17.67	2026-10-22 03:03:53.927+07	2026-10-22 03:03:53.933742+07
4360	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	55	0	22.33	2026-10-22 03:03:53.929+07	2026-10-22 03:03:53.935422+07
4361	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	220	75	0	2026-10-22 03:03:57.4+07	2026-10-22 03:03:57.406503+07
4362	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	225	75	0	2026-10-22 03:03:57.4+07	2026-10-22 03:03:57.40939+07
4363	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	236	75	0	2026-10-22 03:04:00.91+07	2026-10-22 03:04:00.918851+07
4364	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	241	75	0	2026-10-22 03:04:00.912+07	2026-10-22 03:04:00.922384+07
4365	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	231	75	0	2026-10-22 03:04:04.408+07	2026-10-22 03:04:04.412612+07
4366	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	242	75	0	2026-10-22 03:04:04.408+07	2026-10-22 03:04:04.414727+07
4367	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	231	75	0	2026-10-22 03:04:07.912+07	2026-10-22 03:04:07.917082+07
4368	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	236	75	0	2026-10-22 03:04:07.912+07	2026-10-22 03:04:07.918936+07
4369	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	242	75	0	2026-10-22 03:04:11.409+07	2026-10-22 03:04:11.417502+07
4370	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	232	75	0	2026-10-22 03:04:11.41+07	2026-10-22 03:04:11.421688+07
4371	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	223	75	0	2026-10-22 03:04:14.904+07	2026-10-22 03:04:14.9089+07
4372	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	218	75	0	2026-10-22 03:04:14.904+07	2026-10-22 03:04:14.911581+07
4373	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	241	75	0	2026-10-22 03:04:18.407+07	2026-10-22 03:04:18.41198+07
4374	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	232	75	0	2026-10-22 03:04:18.407+07	2026-10-22 03:04:18.414397+07
4375	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	231	75	0	2026-10-22 03:04:21.901+07	2026-10-22 03:04:21.906037+07
4376	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	238	75	0	2026-10-22 03:04:21.901+07	2026-10-22 03:04:21.909304+07
4377	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	237	75	0	2026-10-22 03:04:25.4+07	2026-10-22 03:04:25.906515+07
4378	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 03:04:25.901+07	2026-10-22 03:04:25.908832+07
4379	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	239	75	0	2026-10-22 03:04:29.408+07	2026-10-22 03:04:29.413728+07
4380	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	234	75	0	2026-10-22 03:04:29.408+07	2026-10-22 03:04:29.416281+07
4385	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	56	0	38.33	2026-10-22 03:04:35.386+07	2026-10-22 03:04:37.910918+07
4386	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	252	75	0	2026-10-22 03:04:37.901+07	2026-10-22 03:04:37.921864+07
4387	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	54	0	26.33	2026-10-22 03:04:38.921+07	2026-10-22 03:04:41.406704+07
4388	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	239	75	0	2026-10-22 03:04:41.402+07	2026-10-22 03:04:41.409101+07
4389	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	247	75	0	2026-10-22 03:04:44.913+07	2026-10-22 03:04:44.917975+07
4390	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	235	75	0	2026-10-22 03:04:44.913+07	2026-10-22 03:04:44.919995+07
4393	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	240	75	0	2026-10-22 03:04:51.91+07	2026-10-22 03:04:51.91818+07
4394	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	235	75	0	2026-10-22 03:04:51.91+07	2026-10-22 03:04:51.920727+07
4395	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	248	75	0	2026-10-22 03:04:55.404+07	2026-10-22 03:04:55.410704+07
4396	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	253	75	0	2026-10-22 03:04:55.404+07	2026-10-22 03:04:55.413449+07
4397	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	232	75	0	2026-10-22 03:04:58.914+07	2026-10-22 03:04:58.918516+07
4398	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	239	75	0	2026-10-22 03:04:58.914+07	2026-10-22 03:04:58.920902+07
4399	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	241	75	0	2026-10-22 03:05:02.404+07	2026-10-22 03:05:02.408792+07
4400	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	237	75	0	2026-10-22 03:05:02.404+07	2026-10-22 03:05:02.410638+07
4401	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	243	75	0	2026-10-22 03:05:05.903+07	2026-10-22 03:05:05.908861+07
4402	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	39	0	2.33	2026-10-22 03:08:33.711+07	2026-10-22 03:08:33.723127+07
4403	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	40	0	7.67	2026-10-22 03:08:33.716+07	2026-10-22 03:08:33.733931+07
4404	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	244	75	0	2026-10-22 03:08:35.912+07	2026-10-22 03:08:36.415802+07
4405	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	229	75	0	2026-10-22 03:08:36.411+07	2026-10-22 03:08:36.41785+07
4406	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	233	75	0	2026-10-22 03:08:39.916+07	2026-10-22 03:08:39.924373+07
4407	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	240	75	0	2026-10-22 03:08:39.916+07	2026-10-22 03:08:39.927655+07
4408	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	222	75	0	2026-10-22 03:08:43.415+07	2026-10-22 03:08:43.42245+07
4409	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	211	75	0	2026-10-22 03:08:43.415+07	2026-10-22 03:08:43.425547+07
4410	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	237	75	0	2026-10-22 03:08:46.913+07	2026-10-22 03:08:46.918997+07
4411	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	242	75	0	2026-10-22 03:08:46.913+07	2026-10-22 03:08:46.922405+07
4412	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	242	75	0	2026-10-22 03:08:50.404+07	2026-10-22 03:08:50.408606+07
4413	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	232	75	0	2026-10-22 03:08:50.404+07	2026-10-22 03:08:50.410679+07
4414	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	239	75	0	2026-10-22 03:08:53.902+07	2026-10-22 03:08:53.906576+07
4415	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	229	75	0	2026-10-22 03:08:53.902+07	2026-10-22 03:08:53.908326+07
4416	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	238	75	0	2026-10-22 03:08:57.401+07	2026-10-22 03:08:57.406705+07
4417	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	243	75	0	2026-10-22 03:08:57.401+07	2026-10-22 03:08:57.409056+07
4418	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	50	0	13	2026-10-22 03:08:58.38+07	2026-10-22 03:09:00.915549+07
4419	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	239	75	0	2026-10-22 03:09:00.909+07	2026-10-22 03:09:00.91897+07
4420	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	224	75	0	2026-10-22 03:09:04.408+07	2026-10-22 03:09:04.41612+07
4421	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	221	75	0	2026-10-22 03:09:04.408+07	2026-10-22 03:09:04.418237+07
4422	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	35	0	8.33	2026-10-22 03:09:05.342+07	2026-10-22 03:09:07.920892+07
4423	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	241	75	0	2026-10-22 03:09:07.914+07	2026-10-22 03:09:07.924041+07
4424	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	238	75	0	2026-10-22 03:09:11.418+07	2026-10-22 03:09:11.426318+07
4425	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	227	75	0	2026-10-22 03:09:11.418+07	2026-10-22 03:09:11.431033+07
4426	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	244	75	0	2026-10-22 03:09:14.914+07	2026-10-22 03:09:14.918602+07
4427	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	242	75	0	2026-10-22 03:09:14.914+07	2026-10-22 03:09:14.920439+07
4428	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	226	75	0	2026-10-22 03:09:18.408+07	2026-10-22 03:09:18.412614+07
4429	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	237	75	0	2026-10-22 03:09:18.408+07	2026-10-22 03:09:18.414439+07
4430	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	234	75	0	2026-10-22 03:09:21.901+07	2026-10-22 03:09:21.907425+07
4431	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	239	75	0	2026-10-22 03:09:21.9+07	2026-10-22 03:09:21.909302+07
4432	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	236	75	0	2026-10-22 03:09:25.416+07	2026-10-22 03:09:25.421905+07
4433	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	240	75	0	2026-10-22 03:09:25.416+07	2026-10-22 03:09:25.424662+07
4434	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	228	75	0	2026-10-22 03:09:28.908+07	2026-10-22 03:09:28.912713+07
4435	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	239	75	0	2026-10-22 03:09:28.908+07	2026-10-22 03:09:28.915503+07
4436	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	244	75	0	2026-10-22 03:09:32.417+07	2026-10-22 03:09:32.421747+07
4437	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	232	75	0	2026-10-22 03:09:32.417+07	2026-10-22 03:09:32.423487+07
4438	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	226	75	0	2026-10-22 03:09:35.914+07	2026-10-22 03:09:35.917851+07
4439	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	237	75	0	2026-10-22 03:09:35.914+07	2026-10-22 03:09:35.919499+07
4440	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	236	75	0	2026-10-22 03:09:39.413+07	2026-10-22 03:09:39.418992+07
4441	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	232	75	0	2026-10-22 03:09:39.413+07	2026-10-22 03:09:39.421731+07
4442	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	235	75	0	2026-10-22 03:09:42.9+07	2026-10-22 03:09:42.905379+07
4443	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	246	75	0	2026-10-22 03:09:42.9+07	2026-10-22 03:09:42.907489+07
4444	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	238	75	0	2026-10-22 03:09:46.412+07	2026-10-22 03:09:46.41674+07
4445	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	241	75	0	2026-10-22 03:09:46.412+07	2026-10-22 03:09:46.418472+07
4446	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	242	75	0	2026-10-22 03:09:49.902+07	2026-10-22 03:09:49.906583+07
4447	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	239	75	0	2026-10-22 03:09:49.902+07	2026-10-22 03:09:49.908476+07
4448	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	225	75	0	2026-10-22 03:09:53.403+07	2026-10-22 03:09:53.409571+07
4449	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	236	75	0	2026-10-22 03:09:53.403+07	2026-10-22 03:09:53.411466+07
4450	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	238	75	0	2026-10-22 03:09:56.907+07	2026-10-22 03:09:56.911283+07
4451	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	233	75	0	2026-10-22 03:09:56.907+07	2026-10-22 03:09:56.91315+07
4452	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	212	75	0	2026-10-22 03:10:00.417+07	2026-10-22 03:10:00.423978+07
4453	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	236	75	0	2026-10-22 03:10:00.417+07	2026-10-22 03:10:00.426735+07
4454	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	233	75	0	2026-10-22 03:10:03.903+07	2026-10-22 03:10:03.912648+07
4455	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	239	75	0	2026-10-22 03:10:03.903+07	2026-10-22 03:10:03.915717+07
4456	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	240	75	0	2026-10-22 03:10:07.402+07	2026-10-22 03:10:07.408437+07
4457	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	235	75	0	2026-10-22 03:10:07.402+07	2026-10-22 03:10:07.411267+07
4458	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	232	75	0	2026-10-22 03:10:10.911+07	2026-10-22 03:10:10.921558+07
4459	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	239	75	0	2026-10-22 03:10:10.912+07	2026-10-22 03:10:10.92562+07
4460	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	245	75	0	2026-10-22 03:10:14.415+07	2026-10-22 03:10:14.420182+07
4461	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	235	75	0	2026-10-22 03:10:14.415+07	2026-10-22 03:10:14.422332+07
4462	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	239	75	0	2026-10-22 03:10:17.905+07	2026-10-22 03:10:17.911285+07
4463	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	231	75	0	2026-10-22 03:10:17.905+07	2026-10-22 03:10:17.913978+07
4464	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	243	75	0	2026-10-22 03:10:21.409+07	2026-10-22 03:10:21.416057+07
4465	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	232	75	0	2026-10-22 03:10:21.409+07	2026-10-22 03:10:21.419486+07
4466	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	237	75	0	2026-10-22 03:10:24.913+07	2026-10-22 03:10:24.920282+07
4467	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	241	75	0	2026-10-22 03:10:24.913+07	2026-10-22 03:10:24.923232+07
4468	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	233	75	0	2026-10-22 03:10:28.402+07	2026-10-22 03:10:28.406644+07
4469	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	244	75	0	2026-10-22 03:10:28.402+07	2026-10-22 03:10:28.408663+07
4470	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	232	75	0	2026-10-22 03:10:31.915+07	2026-10-22 03:10:31.919718+07
4471	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	235	75	0	2026-10-22 03:10:31.915+07	2026-10-22 03:10:31.921394+07
4472	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	218	75	0	2026-10-22 03:10:35.406+07	2026-10-22 03:10:35.412432+07
4473	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	230	75	0	2026-10-22 03:10:35.406+07	2026-10-22 03:10:35.417062+07
4474	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	231	75	0	2026-10-22 03:10:38.903+07	2026-10-22 03:10:38.908141+07
4475	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	238	75	0	2026-10-22 03:10:38.903+07	2026-10-22 03:10:38.909867+07
4476	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	229	75	0	2026-10-22 03:10:42.402+07	2026-10-22 03:10:42.414492+07
4477	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	239	75	0	2026-10-22 03:10:42.403+07	2026-10-22 03:10:42.418705+07
4478	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	234	75	0	2026-10-22 03:10:45.905+07	2026-10-22 03:10:45.910704+07
4479	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	238	75	0	2026-10-22 03:10:45.906+07	2026-10-22 03:10:45.913822+07
4480	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-22 03:10:48.405+07	2026-10-22 03:10:48.410273+07
4481	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	235	75	0	2026-10-22 03:10:48.405+07	2026-10-22 03:10:48.41288+07
4482	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	237	75	0	2026-10-22 03:10:51.904+07	2026-10-22 03:10:51.908036+07
4483	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	232	75	0	2026-10-22 03:10:51.904+07	2026-10-22 03:10:51.909633+07
4484	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	232	75	0	2026-10-22 03:10:55.409+07	2026-10-22 03:10:55.413207+07
4485	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	236	75	0	2026-10-22 03:10:55.409+07	2026-10-22 03:10:55.415225+07
4486	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	236	75	0	2026-10-22 03:10:58.914+07	2026-10-22 03:10:58.917627+07
4487	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	241	75	0	2026-10-22 03:10:58.914+07	2026-10-22 03:10:58.919321+07
4488	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	238	75	0	2026-10-22 03:11:02.409+07	2026-10-22 03:11:02.41829+07
4489	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	242	75	0	2026-10-22 03:11:02.409+07	2026-10-22 03:11:02.421134+07
4490	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	225	75	0	2026-10-22 03:11:05.901+07	2026-10-22 03:11:05.905127+07
4491	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	219	75	0	2026-10-22 03:11:05.901+07	2026-10-22 03:11:05.907082+07
4492	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	239	75	0	2026-10-22 03:11:09.399+07	2026-10-22 03:11:09.403039+07
4493	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	235	75	0	2026-10-22 03:11:09.399+07	2026-10-22 03:11:09.404776+07
4494	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	38	0	4.67	2026-10-22 03:11:10.332+07	2026-10-22 03:11:12.915976+07
4495	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	240	75	0	2026-10-22 03:11:12.911+07	2026-10-22 03:11:12.918112+07
4496	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	238	75	0	2026-10-22 03:11:16.4+07	2026-10-22 03:11:16.40467+07
4497	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	215	75	0	2026-10-22 03:11:16.4+07	2026-10-22 03:11:16.406704+07
4498	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	43	0	8.67	2026-10-22 03:11:17.359+07	2026-10-22 03:11:19.917345+07
4499	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	237	75	0	2026-10-22 03:11:19.912+07	2026-10-22 03:11:19.919739+07
4500	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	246	75	0	2026-10-22 03:11:23.402+07	2026-10-22 03:11:23.407134+07
4501	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	240	75	0	2026-10-22 03:11:23.402+07	2026-10-22 03:11:23.409621+07
4502	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	237	75	0	2026-10-22 03:11:26.911+07	2026-10-22 03:11:26.915944+07
4503	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	231	75	0	2026-10-22 03:11:26.911+07	2026-10-22 03:11:26.917823+07
4504	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	237	75	0	2026-10-22 03:11:30.404+07	2026-10-22 03:11:30.40988+07
4505	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	233	75	0	2026-10-22 03:11:30.404+07	2026-10-22 03:11:30.41289+07
4506	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	233	75	0	2026-10-22 03:11:33.915+07	2026-10-22 03:11:33.92044+07
4507	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	237	75	0	2026-10-22 03:11:33.914+07	2026-10-22 03:11:33.922985+07
4508	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	234	75	0	2026-10-22 03:11:37.414+07	2026-10-22 03:11:37.418135+07
4509	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	238	75	0	2026-10-22 03:11:37.414+07	2026-10-22 03:11:37.419902+07
4510	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	235	75	0	2026-10-22 03:11:40.914+07	2026-10-22 03:11:40.921202+07
4511	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	240	75	0	2026-10-22 03:11:40.914+07	2026-10-22 03:11:40.923954+07
4512	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	250	75	0	2026-10-22 03:11:44.402+07	2026-10-22 03:11:44.407334+07
4513	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	254	75	0	2026-10-22 03:11:44.402+07	2026-10-22 03:11:44.409928+07
4514	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	245	75	0	2026-10-22 03:11:47.913+07	2026-10-22 03:11:47.917629+07
4515	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	234	75	0	2026-10-22 03:11:47.913+07	2026-10-22 03:11:47.919911+07
4516	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	240	75	0	2026-10-22 03:11:51.414+07	2026-10-22 03:11:51.421128+07
4517	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	235	75	0	2026-10-22 03:11:51.414+07	2026-10-22 03:11:51.423428+07
4518	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	239	75	0	2026-10-22 03:11:54.907+07	2026-10-22 03:11:54.913219+07
4519	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	233	75	0	2026-10-22 03:11:54.907+07	2026-10-22 03:11:54.915987+07
4520	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	239	75	0	2026-10-22 03:11:58.411+07	2026-10-22 03:11:58.416685+07
4521	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	244	75	0	2026-10-22 03:11:58.411+07	2026-10-22 03:11:58.419296+07
4522	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	237	75	0	2026-10-22 03:12:01.909+07	2026-10-22 03:12:01.913745+07
4523	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	242	75	0	2026-10-22 03:12:01.909+07	2026-10-22 03:12:01.916123+07
4524	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	239	75	0	2026-10-22 03:12:05.411+07	2026-10-22 03:12:05.415918+07
4525	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	232	75	0	2026-10-22 03:12:05.411+07	2026-10-22 03:12:05.417874+07
4526	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	228	75	0	2026-10-22 03:12:08.905+07	2026-10-22 03:12:08.913575+07
4527	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	217	75	0	2026-10-22 03:12:08.905+07	2026-10-22 03:12:08.917036+07
4528	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	238	75	0	2026-10-22 03:12:12.4+07	2026-10-22 03:12:12.404024+07
4529	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	234	75	0	2026-10-22 03:12:12.4+07	2026-10-22 03:12:12.405814+07
4530	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	232	75	0	2026-10-22 03:12:15.915+07	2026-10-22 03:12:15.92354+07
4531	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	238	75	0	2026-10-22 03:12:15.915+07	2026-10-22 03:12:15.926783+07
4532	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	234	75	0	2026-10-22 03:12:19.401+07	2026-10-22 03:12:19.405791+07
4533	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	238	75	0	2026-10-22 03:12:19.401+07	2026-10-22 03:12:19.408037+07
4534	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	238	75	0	2026-10-22 03:12:22.909+07	2026-10-22 03:12:22.913575+07
4535	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	232	75	0	2026-10-22 03:12:22.909+07	2026-10-22 03:12:22.916135+07
4536	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	234	75	0	2026-10-22 03:12:26.41+07	2026-10-22 03:12:26.415289+07
4537	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	238	75	0	2026-10-22 03:12:26.41+07	2026-10-22 03:12:26.417884+07
4538	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	240	75	0	2026-10-22 03:12:29.908+07	2026-10-22 03:12:29.912547+07
4539	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	228	75	0	2026-10-22 03:12:29.908+07	2026-10-22 03:12:29.915402+07
4540	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	240	75	0	2026-10-22 03:12:33.407+07	2026-10-22 03:12:33.411684+07
4541	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	244	75	0	2026-10-22 03:12:33.407+07	2026-10-22 03:12:33.414132+07
4542	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	235	75	0	2026-10-22 03:12:36.914+07	2026-10-22 03:12:36.919807+07
4543	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	239	75	0	2026-10-22 03:12:36.914+07	2026-10-22 03:12:36.922243+07
4544	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	227	75	0	2026-10-22 03:12:40.403+07	2026-10-22 03:12:40.407368+07
4545	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	239	75	0	2026-10-22 03:12:40.403+07	2026-10-22 03:12:40.409536+07
4546	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	234	75	0	2026-10-22 03:12:43.907+07	2026-10-22 03:12:43.911017+07
4547	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	238	75	0	2026-10-22 03:12:43.907+07	2026-10-22 03:12:43.91321+07
4548	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	232	75	0	2026-10-22 03:12:47.407+07	2026-10-22 03:12:47.411446+07
4549	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	237	75	0	2026-10-22 03:12:47.407+07	2026-10-22 03:12:47.413465+07
4550	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	238	75	0	2026-10-22 03:12:50.912+07	2026-10-22 03:12:50.91639+07
4551	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	233	75	0	2026-10-22 03:12:50.912+07	2026-10-22 03:12:50.918102+07
4552	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	233	75	0	2026-10-22 03:12:54.409+07	2026-10-22 03:12:54.414093+07
4553	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	238	75	0	2026-10-22 03:12:54.409+07	2026-10-22 03:12:54.415892+07
4554	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	239	75	0	2026-10-22 03:12:57.911+07	2026-10-22 03:12:57.915524+07
4555	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	235	75	0	2026-10-22 03:12:57.911+07	2026-10-22 03:12:57.917382+07
4560	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	42	0	12.67	2026-10-22 03:13:05.861+07	2026-10-22 03:13:08.411534+07
4561	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	237	75	0	2026-10-22 03:13:08.407+07	2026-10-22 03:13:08.413842+07
4562	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	46	0	15.67	2026-10-22 03:13:09.384+07	2026-10-22 03:13:09.388236+07
4563	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	41	0	6.33	2026-10-22 03:13:09.367+07	2026-10-22 03:13:09.38978+07
4564	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	235	75	0	2026-10-22 03:13:12.91+07	2026-10-22 03:13:12.917875+07
4565	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	239	75	0	2026-10-22 03:13:12.909+07	2026-10-22 03:13:12.922091+07
4566	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	253	75	0	2026-10-22 03:13:16.414+07	2026-10-22 03:13:16.426902+07
4567	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	250	75	0	2026-10-22 03:13:16.414+07	2026-10-22 03:13:16.430244+07
4568	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	234	75	0	2026-10-22 03:13:19.906+07	2026-10-22 03:13:19.919883+07
4569	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	238	75	0	2026-10-22 03:13:19.905+07	2026-10-22 03:13:19.922501+07
4570	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	232	75	0	2026-10-22 03:13:23.403+07	2026-10-22 03:13:23.415117+07
4571	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	241	75	0	2026-10-22 03:13:23.402+07	2026-10-22 03:13:23.416878+07
4594	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	237	75	0	2026-10-22 03:14:03.907+07	2026-10-22 03:14:03.913052+07
4595	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	241	75	0	2026-10-22 03:14:03.907+07	2026-10-22 03:14:03.914984+07
4596	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	239	75	0	2026-10-22 03:14:07.408+07	2026-10-22 03:14:07.413738+07
4597	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	234	75	0	2026-10-22 03:14:07.408+07	2026-10-22 03:14:07.416461+07
4598	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	234	75	0	2026-10-22 03:14:10.907+07	2026-10-22 03:14:10.91159+07
4599	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	239	75	0	2026-10-22 03:14:10.908+07	2026-10-22 03:14:10.913291+07
4600	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	232	75	0	2026-10-22 03:14:14.405+07	2026-10-22 03:14:14.408689+07
4601	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	236	75	0	2026-10-22 03:14:14.404+07	2026-10-22 03:14:14.410645+07
4935	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	248	75	0	2026-10-22 03:37:01.409+07	2026-10-22 03:37:01.415525+07
5205	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	720	75	0	2026-10-22 03:45:23.401+07	2026-10-22 03:45:23.409616+07
5206	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	712	75	0	2026-10-22 03:45:23.401+07	2026-10-22 03:45:23.411532+07
5207	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	65	0	14	2026-10-22 03:45:20.509+07	2026-10-22 03:45:23.413938+07
5208	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	742	75	0	2026-10-22 03:45:27.407+07	2026-10-22 03:45:27.41113+07
5209	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	733	75	0	2026-10-22 03:45:27.407+07	2026-10-22 03:45:27.413192+07
5210	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	728	75	0	2026-10-22 03:45:27.407+07	2026-10-22 03:45:27.415386+07
5211	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	65	0	36.67	2026-10-22 03:45:24.479+07	2026-10-22 03:45:27.417175+07
4556	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	235	75	0	2026-10-22 03:13:01.404+07	2026-10-22 03:13:01.410167+07
4557	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	230	75	0	2026-10-22 03:13:01.404+07	2026-10-22 03:13:01.413436+07
4558	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	249	75	0	2026-10-22 03:13:04.906+07	2026-10-22 03:13:04.910809+07
4559	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	253	75	0	2026-10-22 03:13:04.906+07	2026-10-22 03:13:04.913493+07
4572	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	251	75	0	2026-10-22 03:13:26.912+07	2026-10-22 03:13:26.917295+07
4573	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	255	75	0	2026-10-22 03:13:26.912+07	2026-10-22 03:13:26.919797+07
4574	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	238	75	0	2026-10-22 03:13:30.401+07	2026-10-22 03:13:30.405467+07
4575	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	242	75	0	2026-10-22 03:13:30.401+07	2026-10-22 03:13:30.407915+07
4576	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	237	75	0	2026-10-22 03:13:33.9+07	2026-10-22 03:13:33.954787+07
4577	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	232	75	0	2026-10-22 03:13:33.9+07	2026-10-22 03:13:33.95861+07
4578	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	229	75	0	2026-10-22 03:13:37.403+07	2026-10-22 03:13:37.413638+07
4579	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	233	75	0	2026-10-22 03:13:37.403+07	2026-10-22 03:13:37.415296+07
4580	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	245	75	0	2026-10-22 03:13:40.906+07	2026-10-22 03:13:41.410054+07
4581	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 03:13:41.405+07	2026-10-22 03:13:41.412689+07
4582	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	239	75	0	2026-10-22 03:13:44.906+07	2026-10-22 03:13:44.912603+07
4583	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	235	75	0	2026-10-22 03:13:44.906+07	2026-10-22 03:13:44.915019+07
4584	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 03:13:48.9+07	2026-10-22 03:13:48.904663+07
4585	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	135	0	25.67	2026-10-22 03:13:46.23+07	2026-10-22 03:13:48.906989+07
4586	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	57	0	16.67	2026-10-22 03:13:49.916+07	2026-10-22 03:13:49.925218+07
4587	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	54	0	12.33	2026-10-22 03:13:49.921+07	2026-10-22 03:13:49.92716+07
4588	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	61	0	22.67	2026-10-22 03:13:50.962+07	2026-10-22 03:13:53.414701+07
4589	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	237	75	0	2026-10-22 03:13:53.409+07	2026-10-22 03:13:53.417004+07
4590	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	46	0	12	2026-10-22 03:13:54.38+07	2026-10-22 03:13:56.916903+07
4591	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	238	75	0	2026-10-22 03:13:56.912+07	2026-10-22 03:13:56.918879+07
4592	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	239	75	0	2026-10-22 03:14:00.413+07	2026-10-22 03:14:00.420912+07
4593	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	229	75	0	2026-10-22 03:14:00.413+07	2026-10-22 03:14:00.425441+07
4602	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	243	75	0	2026-10-22 03:14:17.912+07	2026-10-22 03:14:17.918062+07
4603	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	232	75	0	2026-10-22 03:14:17.912+07	2026-10-22 03:14:17.920602+07
4604	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	222	75	0	2026-10-22 03:14:21.408+07	2026-10-22 03:14:21.412611+07
4605	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	106	0	60.67	2026-10-22 03:17:10.109+07	2026-10-22 03:17:12.410423+07
4606	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	234	75	0	2026-10-22 03:17:51.913+07	2026-10-22 03:17:51.917221+07
4607	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	230	75	0	2026-10-22 03:20:04.906+07	2026-10-22 03:20:04.913981+07
4608	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	237	75	0	2026-10-22 03:20:04.906+07	2026-10-22 03:20:04.917037+07
4609	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	240	75	0	2026-10-22 03:20:08.403+07	2026-10-22 03:20:08.408891+07
4610	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	244	75	0	2026-10-22 03:20:08.403+07	2026-10-22 03:20:08.411167+07
4611	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	240	75	0	2026-10-22 03:20:11.91+07	2026-10-22 03:20:11.915542+07
4612	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	236	75	0	2026-10-22 03:20:11.91+07	2026-10-22 03:20:11.918056+07
4613	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	227	75	0	2026-10-22 03:20:15.413+07	2026-10-22 03:20:15.41893+07
4614	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	250	75	0	2026-10-22 03:20:15.413+07	2026-10-22 03:20:15.421845+07
4615	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	227	75	0	2026-10-22 03:20:18.912+07	2026-10-22 03:20:18.921344+07
4616	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	248	75	0	2026-10-22 03:20:18.912+07	2026-10-22 03:20:18.923874+07
4617	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	\N	100	0	2026-10-22 03:20:20.439+07	2026-10-22 03:20:20.454764+07
4618	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	\N	100	0	2026-10-22 03:20:20.439+07	2026-10-22 03:20:20.458169+07
4619	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	\N	100	0	2026-10-22 03:20:20.426+07	2026-10-22 03:20:20.461186+07
4620	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	\N	100	0	2026-10-22 03:20:20.442+07	2026-10-22 03:20:20.463732+07
4621	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	\N	100	0	2026-10-22 03:20:20.442+07	2026-10-22 03:20:20.466835+07
4622	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	694	75	0	2026-10-22 03:20:20.438+07	2026-10-22 03:20:20.469502+07
4623	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	unknown	707	50	52	2026-10-22 03:20:23.412+07	2026-10-22 03:20:23.417489+07
4624	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	unknown	699	50	77	2026-10-22 03:20:23.412+07	2026-10-22 03:20:23.419928+07
4625	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	unknown	703	50	74	2026-10-22 03:20:23.412+07	2026-10-22 03:20:23.421794+07
4626	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	unknown	695	50	66	2026-10-22 03:20:23.412+07	2026-10-22 03:20:23.423578+07
4627	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	unknown	683	50	81	2026-10-22 03:20:23.412+07	2026-10-22 03:20:23.42559+07
4628	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	729	75	0	2026-10-22 03:20:27.41+07	2026-10-22 03:20:27.415975+07
4629	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	748	75	0	2026-10-22 03:20:27.41+07	2026-10-22 03:20:27.418795+07
4630	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	723	75	0	2026-10-22 03:20:27.41+07	2026-10-22 03:20:27.421208+07
4631	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	736	75	0	2026-10-22 03:20:27.41+07	2026-10-22 03:20:27.423227+07
4632	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	742	75	0	2026-10-22 03:20:27.41+07	2026-10-22 03:20:27.425178+07
4633	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	228	75	0	2026-10-22 03:20:30.918+07	2026-10-22 03:20:30.925076+07
4634	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	232	75	0	2026-10-22 03:20:30.918+07	2026-10-22 03:20:30.928204+07
4635	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	236	75	0	2026-10-22 03:20:30.918+07	2026-10-22 03:20:30.930557+07
4636	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	240	75	0	2026-10-22 03:20:30.919+07	2026-10-22 03:20:30.93278+07
4637	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	60	0	15.67	2026-10-22 03:20:28.471+07	2026-10-22 03:20:30.935007+07
4638	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	249	75	0	2026-10-22 03:20:34.414+07	2026-10-22 03:20:34.420123+07
4639	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	253	75	0	2026-10-22 03:20:34.415+07	2026-10-22 03:20:34.4222+07
4640	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	244	75	0	2026-10-22 03:20:34.415+07	2026-10-22 03:20:34.424067+07
4641	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	67	0	15.33	2026-10-22 03:20:31.982+07	2026-10-22 03:20:34.425819+07
4642	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	258	75	0	2026-10-22 03:20:34.415+07	2026-10-22 03:20:34.42772+07
4643	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	238	75	0	2026-10-22 03:20:37.915+07	2026-10-22 03:20:37.922518+07
4644	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	246	75	0	2026-10-22 03:20:37.915+07	2026-10-22 03:20:37.925194+07
4645	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	221	75	0	2026-10-22 03:20:37.915+07	2026-10-22 03:20:37.927323+07
4646	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	214	75	0	2026-10-22 03:20:37.915+07	2026-10-22 03:20:37.92944+07
4647	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	229	75	0	2026-10-22 03:20:37.915+07	2026-10-22 03:20:37.931603+07
4648	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	229	75	0	2026-10-22 03:20:41.407+07	2026-10-22 03:20:41.412984+07
4649	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	237	75	0	2026-10-22 03:20:41.407+07	2026-10-22 03:20:41.415588+07
4650	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	234	75	0	2026-10-22 03:20:41.407+07	2026-10-22 03:20:41.417922+07
4651	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	245	75	0	2026-10-22 03:20:41.407+07	2026-10-22 03:20:41.420149+07
4652	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	242	75	0	2026-10-22 03:20:41.407+07	2026-10-22 03:20:41.421914+07
4653	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	226	75	0	2026-10-22 03:20:44.905+07	2026-10-22 03:20:44.909867+07
4654	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	246	75	0	2026-10-22 03:20:44.905+07	2026-10-22 03:20:44.91157+07
4655	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	231	75	0	2026-10-22 03:20:44.905+07	2026-10-22 03:20:44.913174+07
4656	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	236	75	0	2026-10-22 03:20:44.905+07	2026-10-22 03:20:44.915432+07
4657	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	241	75	0	2026-10-22 03:20:44.905+07	2026-10-22 03:20:44.918113+07
4658	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	235	75	0	2026-10-22 03:20:48.406+07	2026-10-22 03:20:48.411809+07
4659	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	238	75	0	2026-10-22 03:20:48.406+07	2026-10-22 03:20:48.41535+07
4660	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	242	75	0	2026-10-22 03:20:48.405+07	2026-10-22 03:20:48.418201+07
4661	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	231	75	0	2026-10-22 03:20:48.405+07	2026-10-22 03:20:48.420433+07
4662	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	226	75	0	2026-10-22 03:20:48.406+07	2026-10-22 03:20:48.422332+07
4663	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	242	75	0	2026-10-22 03:20:51.922+07	2026-10-22 03:20:51.929202+07
4664	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	233	75	0	2026-10-22 03:20:51.922+07	2026-10-22 03:20:51.931919+07
4665	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	246	75	0	2026-10-22 03:20:51.922+07	2026-10-22 03:20:51.934514+07
4666	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	238	75	0	2026-10-22 03:20:51.922+07	2026-10-22 03:20:51.93693+07
4667	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	228	75	0	2026-10-22 03:20:51.922+07	2026-10-22 03:20:51.939015+07
4718	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	241	75	0	2026-10-22 03:21:30.406+07	2026-10-22 03:21:30.412154+07
4719	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	233	75	0	2026-10-22 03:21:30.407+07	2026-10-22 03:21:30.415025+07
4720	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	245	75	0	2026-10-22 03:21:30.406+07	2026-10-22 03:21:30.41827+07
4721	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	248	75	0	2026-10-22 03:21:30.406+07	2026-10-22 03:21:30.420557+07
4722	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	237	75	0	2026-10-22 03:21:30.407+07	2026-10-22 03:21:30.422506+07
4723	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	232	75	0	2026-10-22 03:21:33.909+07	2026-10-22 03:21:34.413128+07
4724	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 03:21:34.408+07	2026-10-22 03:21:34.415516+07
4725	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	227	75	0	2026-10-22 03:21:33.909+07	2026-10-22 03:21:34.417969+07
4726	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	220	75	0	2026-10-22 03:21:33.909+07	2026-10-22 03:21:34.420043+07
4727	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 03:21:34.408+07	2026-10-22 03:21:34.42223+07
4728	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	135	0	36.33	2026-10-22 03:21:35.732+07	2026-10-22 03:21:37.911438+07
4729	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	59	0	8.67	2026-10-22 03:21:35.432+07	2026-10-22 03:21:37.913694+07
4730	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	57	0	13.33	2026-10-22 03:21:35.427+07	2026-10-22 03:21:37.916033+07
4731	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	55	0	17.33	2026-10-22 03:21:35.437+07	2026-10-22 03:21:37.918329+07
4732	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	237	75	0	2026-10-22 03:21:37.907+07	2026-10-22 03:21:37.920469+07
4733	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	69	0	37	2026-10-22 03:21:38.968+07	2026-10-22 03:21:41.4132+07
4734	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	239	75	0	2026-10-22 03:21:41.404+07	2026-10-22 03:21:41.416143+07
4735	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	244	75	0	2026-10-22 03:21:41.404+07	2026-10-22 03:21:41.418919+07
4736	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	231	75	0	2026-10-22 03:21:41.407+07	2026-10-22 03:21:41.421015+07
4737	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	225	75	0	2026-10-22 03:21:41.404+07	2026-10-22 03:21:41.422871+07
4738	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	233	75	0	2026-10-22 03:21:44.915+07	2026-10-22 03:21:44.920798+07
4739	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	240	75	0	2026-10-22 03:21:44.916+07	2026-10-22 03:21:44.922749+07
4668	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	217	75	0	2026-10-22 03:20:55.405+07	2026-10-22 03:20:55.411538+07
4669	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	240	75	0	2026-10-22 03:20:55.405+07	2026-10-22 03:20:55.415308+07
4670	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	254	75	0	2026-10-22 03:20:55.405+07	2026-10-22 03:20:55.417995+07
4671	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	233	75	0	2026-10-22 03:20:55.405+07	2026-10-22 03:20:55.420373+07
4672	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	225	75	0	2026-10-22 03:20:55.405+07	2026-10-22 03:20:55.422427+07
4673	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	241	75	0	2026-10-22 03:20:58.914+07	2026-10-22 03:20:58.919019+07
4674	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	249	75	0	2026-10-22 03:20:58.914+07	2026-10-22 03:20:58.920698+07
4675	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	231	75	0	2026-10-22 03:20:58.914+07	2026-10-22 03:20:58.922304+07
4676	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	246	75	0	2026-10-22 03:20:58.914+07	2026-10-22 03:20:58.924055+07
4677	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	235	75	0	2026-10-22 03:20:58.914+07	2026-10-22 03:20:58.926017+07
4678	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	223	75	0	2026-10-22 03:21:02.418+07	2026-10-22 03:21:02.426449+07
4679	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	210	75	0	2026-10-22 03:21:02.418+07	2026-10-22 03:21:02.429651+07
4680	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	234	75	0	2026-10-22 03:21:02.419+07	2026-10-22 03:21:02.43262+07
4681	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	245	75	0	2026-10-22 03:21:02.418+07	2026-10-22 03:21:02.435513+07
4682	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	202	75	0	2026-10-22 03:21:02.419+07	2026-10-22 03:21:02.437935+07
4683	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	235	75	0	2026-10-22 03:21:05.916+07	2026-10-22 03:21:05.923729+07
4684	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	246	75	0	2026-10-22 03:21:05.916+07	2026-10-22 03:21:05.926027+07
4685	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	201	75	0	2026-10-22 03:21:05.917+07	2026-10-22 03:21:05.927967+07
4686	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	226	75	0	2026-10-22 03:21:05.916+07	2026-10-22 03:21:05.929881+07
4687	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	213	75	0	2026-10-22 03:21:05.916+07	2026-10-22 03:21:05.931932+07
4688	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	231	75	0	2026-10-22 03:21:09.415+07	2026-10-22 03:21:09.42259+07
4689	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	246	75	0	2026-10-22 03:21:09.416+07	2026-10-22 03:21:09.42536+07
4690	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	250	75	0	2026-10-22 03:21:09.416+07	2026-10-22 03:21:09.427613+07
4691	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	237	75	0	2026-10-22 03:21:09.415+07	2026-10-22 03:21:09.429938+07
4692	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	241	75	0	2026-10-22 03:21:09.415+07	2026-10-22 03:21:09.432182+07
4693	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	220	75	0	2026-10-22 03:21:12.915+07	2026-10-22 03:21:12.920983+07
4694	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	247	75	0	2026-10-22 03:21:12.915+07	2026-10-22 03:21:12.923918+07
4695	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	237	75	0	2026-10-22 03:21:12.915+07	2026-10-22 03:21:12.92639+07
4696	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	228	75	0	2026-10-22 03:21:12.915+07	2026-10-22 03:21:12.929134+07
4697	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	214	75	0	2026-10-22 03:21:12.915+07	2026-10-22 03:21:12.933019+07
4698	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	249	75	0	2026-10-22 03:21:16.417+07	2026-10-22 03:21:16.425513+07
4699	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	230	75	0	2026-10-22 03:21:16.417+07	2026-10-22 03:21:16.427917+07
4700	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	238	75	0	2026-10-22 03:21:16.419+07	2026-10-22 03:21:16.430547+07
4701	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	243	75	0	2026-10-22 03:21:16.418+07	2026-10-22 03:21:16.433051+07
4702	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	243	75	0	2026-10-22 03:21:16.418+07	2026-10-22 03:21:16.43538+07
4703	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	64	0	15.33	2026-10-22 03:21:17.476+07	2026-10-22 03:21:19.909972+07
4704	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	212	75	0	2026-10-22 03:21:19.904+07	2026-10-22 03:21:19.913376+07
4705	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	59	0	17.33	2026-10-22 03:21:17.484+07	2026-10-22 03:21:19.917023+07
4706	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	61	0	17	2026-10-22 03:21:17.479+07	2026-10-22 03:21:19.919997+07
4707	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	199	75	0	2026-10-22 03:21:19.904+07	2026-10-22 03:21:19.922574+07
4708	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	223	75	0	2026-10-22 03:21:23.411+07	2026-10-22 03:21:23.416767+07
4709	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	242	75	0	2026-10-22 03:21:23.411+07	2026-10-22 03:21:23.419153+07
4710	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	234	75	0	2026-10-22 03:21:23.411+07	2026-10-22 03:21:23.421238+07
4711	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	250	75	0	2026-10-22 03:21:23.411+07	2026-10-22 03:21:23.423093+07
4712	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	212	75	0	2026-10-22 03:21:23.411+07	2026-10-22 03:21:23.424875+07
4713	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	226	75	0	2026-10-22 03:21:26.902+07	2026-10-22 03:21:26.906064+07
4714	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	245	75	0	2026-10-22 03:21:26.902+07	2026-10-22 03:21:26.907719+07
4715	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	236	75	0	2026-10-22 03:21:26.902+07	2026-10-22 03:21:26.909345+07
4716	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	213	75	0	2026-10-22 03:21:26.902+07	2026-10-22 03:21:26.910957+07
4717	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	220	75	0	2026-10-22 03:21:26.902+07	2026-10-22 03:21:26.912811+07
4743	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	233	75	0	2026-10-22 03:21:48.407+07	2026-10-22 03:21:48.412004+07
4744	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	223	75	0	2026-10-22 03:21:48.406+07	2026-10-22 03:21:48.41529+07
4745	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	227	75	0	2026-10-22 03:21:48.406+07	2026-10-22 03:21:48.417727+07
4746	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	208	75	0	2026-10-22 03:21:48.406+07	2026-10-22 03:21:48.419955+07
4747	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	216	75	0	2026-10-22 03:21:48.407+07	2026-10-22 03:21:48.421747+07
4937	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	194	75	0	2026-10-22 03:39:46.419+07	2026-10-22 03:39:46.434832+07
4938	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	199	75	0	2026-10-22 03:39:46.419+07	2026-10-22 03:39:46.441804+07
4740	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	221	75	0	2026-10-22 03:21:44.915+07	2026-10-22 03:21:44.924553+07
4741	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	226	75	0	2026-10-22 03:21:44.916+07	2026-10-22 03:21:44.926631+07
4742	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	242	75	0	2026-10-22 03:21:44.916+07	2026-10-22 03:21:44.928312+07
4939	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	229	75	0	2026-10-22 03:39:46.419+07	2026-10-22 03:39:46.447006+07
4940	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	233	75	0	2026-10-22 03:39:46.419+07	2026-10-22 03:39:46.452267+07
4941	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	204	75	0	2026-10-22 03:39:46.418+07	2026-10-22 03:39:46.457533+07
4942	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	232	75	0	2026-10-22 03:39:47.418+07	2026-10-22 03:39:47.430332+07
4943	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	223	75	0	2026-10-22 03:39:47.419+07	2026-10-22 03:39:47.436078+07
4944	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	248	75	0	2026-10-22 03:39:47.419+07	2026-10-22 03:39:47.442311+07
4945	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	216	75	0	2026-10-22 03:39:47.419+07	2026-10-22 03:39:47.447365+07
4946	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	241	75	0	2026-10-22 03:39:47.419+07	2026-10-22 03:39:47.452135+07
4947	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	221	75	0	2026-10-22 03:39:50.904+07	2026-10-22 03:39:50.910136+07
4948	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	207	75	0	2026-10-22 03:39:50.904+07	2026-10-22 03:39:50.912479+07
4949	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	224	75	0	2026-10-22 03:39:50.904+07	2026-10-22 03:39:50.91493+07
4950	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	212	75	0	2026-10-22 03:39:50.904+07	2026-10-22 03:39:50.917216+07
4951	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	217	75	0	2026-10-22 03:39:50.904+07	2026-10-22 03:39:50.919355+07
4952	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	229	75	0	2026-10-22 03:39:54.401+07	2026-10-22 03:39:54.406197+07
4953	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	219	75	0	2026-10-22 03:39:54.401+07	2026-10-22 03:39:54.408962+07
4954	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	224	75	0	2026-10-22 03:39:54.401+07	2026-10-22 03:39:54.41156+07
4955	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	213	75	0	2026-10-22 03:39:54.401+07	2026-10-22 03:39:54.413489+07
4956	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	60	0	31	2026-10-22 03:39:51.946+07	2026-10-22 03:39:54.41501+07
4957	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	240	75	0	2026-10-22 03:39:57.921+07	2026-10-22 03:39:57.929217+07
4958	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	246	75	0	2026-10-22 03:39:57.921+07	2026-10-22 03:39:57.932109+07
4959	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	235	75	0	2026-10-22 03:39:57.921+07	2026-10-22 03:39:57.934517+07
4960	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	46	0	23.67	2026-10-22 03:39:55.392+07	2026-10-22 03:39:57.937133+07
4961	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	229	75	0	2026-10-22 03:39:57.921+07	2026-10-22 03:39:57.940061+07
4962	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	222	75	0	2026-10-22 03:40:01.413+07	2026-10-22 03:40:01.417637+07
4963	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	211	75	0	2026-10-22 03:40:01.413+07	2026-10-22 03:40:01.419836+07
4964	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	209	75	0	2026-10-22 03:40:01.411+07	2026-10-22 03:40:01.422568+07
4965	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	235	75	0	2026-10-22 03:40:01.413+07	2026-10-22 03:40:01.425114+07
4966	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	221	75	0	2026-10-22 03:40:01.413+07	2026-10-22 03:40:01.42686+07
4967	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	228	75	0	2026-10-22 03:40:04.908+07	2026-10-22 03:40:04.915057+07
4968	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	199	75	0	2026-10-22 03:40:04.909+07	2026-10-22 03:40:04.917289+07
4969	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	236	75	0	2026-10-22 03:40:04.909+07	2026-10-22 03:40:04.919596+07
4970	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	209	75	0	2026-10-22 03:40:04.91+07	2026-10-22 03:40:04.921918+07
4971	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	218	75	0	2026-10-22 03:40:04.908+07	2026-10-22 03:40:04.924114+07
4982	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	193	75	0	2026-10-22 03:40:15.414+07	2026-10-22 03:40:15.417833+07
4983	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	233	75	0	2026-10-22 03:40:15.413+07	2026-10-22 03:40:15.420225+07
4984	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	243	75	0	2026-10-22 03:40:15.414+07	2026-10-22 03:40:15.422524+07
4985	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	220	75	0	2026-10-22 03:40:15.414+07	2026-10-22 03:40:15.424477+07
4986	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	205	75	0	2026-10-22 03:40:15.413+07	2026-10-22 03:40:15.426221+07
4987	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	233	75	0	2026-10-22 03:40:18.915+07	2026-10-22 03:40:18.92033+07
4988	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	249	75	0	2026-10-22 03:40:18.915+07	2026-10-22 03:40:18.923495+07
4989	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	220	75	0	2026-10-22 03:40:18.915+07	2026-10-22 03:40:18.925661+07
4990	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	226	75	0	2026-10-22 03:40:18.915+07	2026-10-22 03:40:18.927647+07
4991	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	240	75	0	2026-10-22 03:40:18.915+07	2026-10-22 03:40:18.930678+07
4992	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	245	75	0	2026-10-22 03:40:22.403+07	2026-10-22 03:40:22.410876+07
4993	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	252	75	0	2026-10-22 03:40:22.403+07	2026-10-22 03:40:22.412949+07
4994	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	256	75	0	2026-10-22 03:40:22.405+07	2026-10-22 03:40:22.415544+07
4995	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	253	75	0	2026-10-22 03:40:22.403+07	2026-10-22 03:40:22.417912+07
4996	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	240	75	0	2026-10-22 03:40:22.403+07	2026-10-22 03:40:22.420887+07
5002	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	229	75	0	2026-10-22 03:40:29.412+07	2026-10-22 03:40:29.417016+07
5003	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	240	75	0	2026-10-22 03:40:29.412+07	2026-10-22 03:40:29.420263+07
5004	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	236	75	0	2026-10-22 03:40:29.412+07	2026-10-22 03:40:29.423264+07
5005	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	224	75	0	2026-10-22 03:40:29.412+07	2026-10-22 03:40:29.425768+07
5006	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	232	75	0	2026-10-22 03:40:29.412+07	2026-10-22 03:40:29.428134+07
5007	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	237	75	0	2026-10-22 03:40:32.907+07	2026-10-22 03:40:32.911227+07
5008	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	228	75	0	2026-10-22 03:40:32.906+07	2026-10-22 03:40:32.913331+07
5329	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	187	75	0	2026-10-22 03:52:19.922+07	2026-10-22 03:52:19.949289+07
5330	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	244	75	0	2026-10-22 03:52:19.922+07	2026-10-22 03:52:19.954127+07
5331	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	230	75	0	2026-10-22 03:52:23.408+07	2026-10-22 03:52:23.413773+07
5332	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	221	75	0	2026-10-22 03:52:23.408+07	2026-10-22 03:52:23.416281+07
5333	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	233	75	0	2026-10-22 03:52:23.408+07	2026-10-22 03:52:23.419673+07
5334	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	225	75	0	2026-10-22 03:52:23.408+07	2026-10-22 03:52:23.423133+07
5335	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	216	75	0	2026-10-22 03:52:23.408+07	2026-10-22 03:52:23.425595+07
5336	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	248	75	0	2026-10-22 03:52:26.915+07	2026-10-22 03:52:26.923078+07
5337	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	239	75	0	2026-10-22 03:52:26.915+07	2026-10-22 03:52:26.926417+07
5338	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	244	75	0	2026-10-22 03:52:26.915+07	2026-10-22 03:52:26.929069+07
5339	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	233	75	0	2026-10-22 03:52:26.915+07	2026-10-22 03:52:26.931385+07
5340	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	41	0	7.33	2026-10-22 03:52:24.388+07	2026-10-22 03:52:26.933539+07
5341	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	215	75	0	2026-10-22 03:52:30.405+07	2026-10-22 03:52:30.409947+07
5342	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	238	75	0	2026-10-22 03:52:30.405+07	2026-10-22 03:52:30.41189+07
5343	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	227	75	0	2026-10-22 03:52:30.405+07	2026-10-22 03:52:30.413771+07
5344	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	56	0	16.67	2026-10-22 03:52:27.944+07	2026-10-22 03:52:30.416014+07
5345	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	201	75	0	2026-10-22 03:52:30.405+07	2026-10-22 03:52:30.417956+07
5346	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	203	75	0	2026-10-22 03:52:33.918+07	2026-10-22 03:52:33.926193+07
5347	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	250	75	0	2026-10-22 03:52:33.918+07	2026-10-22 03:52:33.928711+07
5348	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	216	75	0	2026-10-22 03:52:33.918+07	2026-10-22 03:52:33.931003+07
5349	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	239	75	0	2026-10-22 03:52:33.914+07	2026-10-22 03:52:33.933238+07
5350	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	228	75	0	2026-10-22 03:52:33.918+07	2026-10-22 03:52:33.935444+07
5351	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	225	75	0	2026-10-22 03:52:37.41+07	2026-10-22 03:52:37.414907+07
5352	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	235	75	0	2026-10-22 03:52:37.41+07	2026-10-22 03:52:37.416706+07
5353	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	217	75	0	2026-10-22 03:52:37.41+07	2026-10-22 03:52:37.418639+07
5354	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	210	75	0	2026-10-22 03:52:37.41+07	2026-10-22 03:52:37.420829+07
5355	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	241	75	0	2026-10-22 03:52:37.41+07	2026-10-22 03:52:37.423348+07
5356	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	202	75	0	2026-10-22 03:52:40.91+07	2026-10-22 03:52:40.920317+07
5357	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	224	75	0	2026-10-22 03:52:40.91+07	2026-10-22 03:52:40.923502+07
5358	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	231	75	0	2026-10-22 03:52:40.91+07	2026-10-22 03:52:40.92594+07
5359	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	209	75	0	2026-10-22 03:52:40.909+07	2026-10-22 03:52:40.92802+07
5360	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	213	75	0	2026-10-22 03:52:40.909+07	2026-10-22 03:52:40.93043+07
5361	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	241	75	0	2026-10-22 03:52:44.408+07	2026-10-22 03:52:44.414594+07
5362	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	221	75	0	2026-10-22 03:52:44.408+07	2026-10-22 03:52:44.417048+07
5363	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	228	75	0	2026-10-22 03:52:44.408+07	2026-10-22 03:52:44.4199+07
5364	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	212	75	0	2026-10-22 03:52:44.408+07	2026-10-22 03:52:44.422726+07
5365	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	234	75	0	2026-10-22 03:52:44.408+07	2026-10-22 03:52:44.424828+07
5366	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	248	75	0	2026-10-22 03:52:47.919+07	2026-10-22 03:52:47.927495+07
5367	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	225	75	0	2026-10-22 03:52:47.919+07	2026-10-22 03:52:47.930316+07
5368	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	243	75	0	2026-10-22 03:52:47.919+07	2026-10-22 03:52:47.932633+07
5369	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	238	75	0	2026-10-22 03:52:47.919+07	2026-10-22 03:52:47.935693+07
5370	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	231	75	0	2026-10-22 03:52:47.919+07	2026-10-22 03:52:47.938837+07
5371	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	199	75	0	2026-10-22 03:52:51.411+07	2026-10-22 03:52:51.416108+07
5372	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	209	75	0	2026-10-22 03:52:51.411+07	2026-10-22 03:52:51.418179+07
5373	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	218	75	0	2026-10-22 03:52:51.411+07	2026-10-22 03:52:51.420263+07
5374	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	226	75	0	2026-10-22 03:52:51.411+07	2026-10-22 03:52:51.422698+07
5375	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	203	75	0	2026-10-22 03:52:51.412+07	2026-10-22 03:52:51.42483+07
5376	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	226	75	0	2026-10-22 03:52:54.914+07	2026-10-22 03:52:54.921153+07
5377	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	213	75	0	2026-10-22 03:52:54.914+07	2026-10-22 03:52:54.924142+07
5378	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	239	75	0	2026-10-22 03:52:54.914+07	2026-10-22 03:52:54.926763+07
5379	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	223	75	0	2026-10-22 03:52:54.912+07	2026-10-22 03:52:54.928985+07
5380	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	210	75	0	2026-10-22 03:52:54.912+07	2026-10-22 03:52:54.931014+07
5381	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	212	75	0	2026-10-22 03:52:58.415+07	2026-10-22 03:52:58.420494+07
5382	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	240	75	0	2026-10-22 03:52:58.415+07	2026-10-22 03:52:58.42293+07
5383	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	206	75	0	2026-10-22 03:52:58.415+07	2026-10-22 03:52:58.424789+07
5384	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	202	75	0	2026-10-22 03:52:58.415+07	2026-10-22 03:52:58.426701+07
5385	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	197	75	0	2026-10-22 03:52:58.416+07	2026-10-22 03:52:58.428413+07
5386	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	255	75	0	2026-10-22 03:53:01.902+07	2026-10-22 03:53:01.907661+07
5387	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	249	75	0	2026-10-22 03:53:01.902+07	2026-10-22 03:53:01.909507+07
5388	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	238	75	0	2026-10-22 03:53:01.902+07	2026-10-22 03:53:01.911402+07
5389	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	251	75	0	2026-10-22 03:53:01.902+07	2026-10-22 03:53:01.913437+07
5390	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	237	75	0	2026-10-22 03:53:01.902+07	2026-10-22 03:53:01.915129+07
5391	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	225	75	0	2026-10-22 03:53:05.415+07	2026-10-22 03:53:05.419815+07
5392	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	245	75	0	2026-10-22 03:53:05.415+07	2026-10-22 03:53:05.42224+07
5393	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	231	75	0	2026-10-22 03:53:05.415+07	2026-10-22 03:53:05.424234+07
5394	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	231	75	0	2026-10-22 03:53:05.415+07	2026-10-22 03:53:05.426298+07
5395	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	236	75	0	2026-10-22 03:53:05.415+07	2026-10-22 03:53:05.428079+07
5396	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	228	75	0	2026-10-22 03:53:08.909+07	2026-10-22 03:53:08.91389+07
5397	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	219	75	0	2026-10-22 03:53:08.909+07	2026-10-22 03:53:08.915861+07
5398	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	212	75	0	2026-10-22 03:53:08.909+07	2026-10-22 03:53:08.918382+07
5399	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	248	75	0	2026-10-22 03:53:08.909+07	2026-10-22 03:53:08.920431+07
5400	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	232	75	0	2026-10-22 03:53:08.908+07	2026-10-22 03:53:08.922593+07
5401	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	227	75	0	2026-10-22 03:53:12.403+07	2026-10-22 03:53:12.408685+07
5402	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	220	75	0	2026-10-22 03:53:12.403+07	2026-10-22 03:53:12.410619+07
5403	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	215	75	0	2026-10-22 03:53:12.403+07	2026-10-22 03:53:12.412633+07
5404	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	204	75	0	2026-10-22 03:53:12.403+07	2026-10-22 03:53:12.414809+07
5405	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	209	75	0	2026-10-22 03:53:12.403+07	2026-10-22 03:53:12.418295+07
5406	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	50	0	17.33	2026-10-22 03:53:13.41+07	2026-10-22 03:53:15.91835+07
5407	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	234	75	0	2026-10-22 03:53:15.914+07	2026-10-22 03:53:15.920351+07
5408	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	51	0	12.33	2026-10-22 03:53:13.417+07	2026-10-22 03:53:15.922862+07
5409	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	48	0	13	2026-10-22 03:53:13.421+07	2026-10-22 03:53:15.92476+07
5410	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	239	75	0	2026-10-22 03:53:15.914+07	2026-10-22 03:53:15.926546+07
5411	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	235	75	0	2026-10-22 03:53:19.406+07	2026-10-22 03:53:19.410853+07
5412	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	240	75	0	2026-10-22 03:53:19.406+07	2026-10-22 03:53:19.412623+07
5413	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	223	75	0	2026-10-22 03:53:19.406+07	2026-10-22 03:53:19.414246+07
5414	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	218	75	0	2026-10-22 03:53:19.406+07	2026-10-22 03:53:19.415834+07
5415	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	228	75	0	2026-10-22 03:53:19.406+07	2026-10-22 03:53:19.417684+07
5416	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	237	75	0	2026-10-22 03:53:22.909+07	2026-10-22 03:53:22.915745+07
5417	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	233	75	0	2026-10-22 03:53:22.909+07	2026-10-22 03:53:22.918336+07
5418	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	228	75	0	2026-10-22 03:53:22.909+07	2026-10-22 03:53:22.92084+07
5419	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	243	75	0	2026-10-22 03:53:22.909+07	2026-10-22 03:53:22.923196+07
5420	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	240	75	0	2026-10-22 03:53:22.91+07	2026-10-22 03:53:22.925425+07
5421	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	237	75	0	2026-10-22 03:53:26.41+07	2026-10-22 03:53:26.414295+07
5422	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	221	75	0	2026-10-22 03:53:26.41+07	2026-10-22 03:53:26.415968+07
5423	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	232	75	0	2026-10-22 03:53:26.41+07	2026-10-22 03:53:26.418126+07
5424	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	226	75	0	2026-10-22 03:53:26.41+07	2026-10-22 03:53:26.42006+07
5425	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	242	75	0	2026-10-22 03:53:26.41+07	2026-10-22 03:53:26.422736+07
5426	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	243	75	0	2026-10-22 03:53:29.907+07	2026-10-22 03:53:30.411326+07
5427	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 03:53:30.405+07	2026-10-22 03:53:30.413939+07
5428	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	225	75	0	2026-10-22 03:53:29.907+07	2026-10-22 03:53:30.416301+07
5429	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	235	75	0	2026-10-22 03:53:29.908+07	2026-10-22 03:53:30.419095+07
5430	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 03:53:30.405+07	2026-10-22 03:53:30.421349+07
5431	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	105	0	70	2026-10-22 03:53:31.617+07	2026-10-22 03:53:33.915493+07
5432	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	51	0	15.67	2026-10-22 03:53:31.41+07	2026-10-22 03:53:33.917591+07
5433	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	50	0	8.67	2026-10-22 03:53:31.414+07	2026-10-22 03:53:33.91963+07
5434	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	52	0	8.67	2026-10-22 03:53:31.424+07	2026-10-22 03:53:33.921512+07
5435	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	238	75	0	2026-10-22 03:53:33.909+07	2026-10-22 03:53:33.923511+07
5436	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	54	0	13	2026-10-22 03:53:34.926+07	2026-10-22 03:53:37.409065+07
5437	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	215	75	0	2026-10-22 03:53:37.404+07	2026-10-22 03:53:37.411016+07
5438	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	225	75	0	2026-10-22 03:53:37.404+07	2026-10-22 03:53:37.412656+07
5439	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	220	75	0	2026-10-22 03:53:37.404+07	2026-10-22 03:53:37.414292+07
5440	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	210	75	0	2026-10-22 03:53:37.404+07	2026-10-22 03:53:37.41599+07
5441	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	236	75	0	2026-10-22 03:53:40.915+07	2026-10-22 03:53:40.921099+07
5442	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	225	75	0	2026-10-22 03:53:40.915+07	2026-10-22 03:53:40.923465+07
5443	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	240	75	0	2026-10-22 03:53:40.915+07	2026-10-22 03:53:40.926002+07
5444	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	243	75	0	2026-10-22 03:53:40.915+07	2026-10-22 03:53:40.927984+07
5445	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	231	75	0	2026-10-22 03:53:40.915+07	2026-10-22 03:53:40.929825+07
5446	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	223	75	0	2026-10-22 03:53:44.412+07	2026-10-22 03:53:44.417157+07
5447	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	228	75	0	2026-10-22 03:53:44.412+07	2026-10-22 03:53:44.419175+07
5448	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	240	75	0	2026-10-22 03:53:44.412+07	2026-10-22 03:53:44.421334+07
5449	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	232	75	0	2026-10-22 03:53:44.412+07	2026-10-22 03:53:44.423571+07
5450	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	235	75	0	2026-10-22 03:53:44.412+07	2026-10-22 03:53:44.425342+07
5451	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	210	75	0	2026-10-22 03:55:10.412+07	2026-10-22 03:55:10.421134+07
5452	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	249	75	0	2026-10-22 03:56:32.917+07	2026-10-22 03:56:32.925345+07
5453	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	215	75	0	2026-10-22 03:57:55.418+07	2026-10-22 03:57:55.426066+07
5454	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	223	75	0	2026-10-22 03:59:12.423+07	2026-10-22 03:59:12.437239+07
5455	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	238	75	0	2026-10-22 03:59:12.424+07	2026-10-22 03:59:12.441582+07
5456	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	233	75	0	2026-10-22 03:59:12.423+07	2026-10-22 03:59:12.4464+07
5457	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	219	75	0	2026-10-22 03:59:12.425+07	2026-10-22 03:59:12.448939+07
5458	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	228	75	0	2026-10-22 03:59:12.423+07	2026-10-22 03:59:12.451108+07
5459	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	219	75	0	2026-10-22 03:59:14.927+07	2026-10-22 03:59:14.937854+07
5460	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	235	75	0	2026-10-22 03:59:14.926+07	2026-10-22 03:59:14.942249+07
5461	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	249	75	0	2026-10-22 03:59:14.926+07	2026-10-22 03:59:14.946515+07
5462	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	229	75	0	2026-10-22 03:59:14.927+07	2026-10-22 03:59:14.949677+07
5463	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	208	75	0	2026-10-22 03:59:14.926+07	2026-10-22 03:59:14.952617+07
5464	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	222	75	0	2026-10-22 03:59:18.407+07	2026-10-22 03:59:18.423609+07
5465	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	215	75	0	2026-10-22 03:59:18.407+07	2026-10-22 03:59:18.428699+07
5466	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	190	75	0	2026-10-22 03:59:18.412+07	2026-10-22 03:59:18.432904+07
5467	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	225	75	0	2026-10-22 03:59:18.407+07	2026-10-22 03:59:18.435506+07
5468	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	230	75	0	2026-10-22 03:59:18.407+07	2026-10-22 03:59:18.437744+07
5469	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	226	75	0	2026-10-22 03:59:21.913+07	2026-10-22 03:59:21.923685+07
5470	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	221	75	0	2026-10-22 03:59:21.913+07	2026-10-22 03:59:21.926892+07
5471	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	232	75	0	2026-10-22 03:59:21.913+07	2026-10-22 03:59:21.929843+07
5472	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	216	75	0	2026-10-22 03:59:21.913+07	2026-10-22 03:59:21.932242+07
5473	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	52	0	13	2026-10-22 03:59:19.441+07	2026-10-22 03:59:21.934198+07
5474	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	253	75	0	2026-10-22 03:59:25.4+07	2026-10-22 03:59:25.408+07
5475	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	241	75	0	2026-10-22 03:59:25.4+07	2026-10-22 03:59:25.411841+07
5476	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	236	75	0	2026-10-22 03:59:25.402+07	2026-10-22 03:59:25.415917+07
5477	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	62	0	18	2026-10-22 03:59:22.97+07	2026-10-22 03:59:25.418976+07
5478	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	247	75	0	2026-10-22 03:59:25.402+07	2026-10-22 03:59:25.420979+07
5479	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	208	75	0	2026-10-22 03:59:28.903+07	2026-10-22 03:59:28.907479+07
5480	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	204	75	0	2026-10-22 03:59:28.903+07	2026-10-22 03:59:28.909614+07
5481	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	196	75	0	2026-10-22 03:59:28.903+07	2026-10-22 03:59:28.911924+07
5482	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	201	75	0	2026-10-22 03:59:28.903+07	2026-10-22 03:59:28.914665+07
5483	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	192	75	0	2026-10-22 03:59:28.903+07	2026-10-22 03:59:28.916681+07
5484	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	185	75	0	2026-10-22 03:59:32.407+07	2026-10-22 03:59:32.415351+07
5485	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	240	75	0	2026-10-22 03:59:32.406+07	2026-10-22 03:59:32.417741+07
5486	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	179	75	0	2026-10-22 03:59:32.406+07	2026-10-22 03:59:32.42012+07
5487	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	176	75	0	2026-10-22 03:59:32.407+07	2026-10-22 03:59:32.422094+07
5488	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	190	75	0	2026-10-22 03:59:32.406+07	2026-10-22 03:59:32.423952+07
5489	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	219	75	0	2026-10-22 03:59:35.904+07	2026-10-22 03:59:35.90877+07
5490	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	208	75	0	2026-10-22 03:59:35.904+07	2026-10-22 03:59:35.911034+07
5491	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	228	75	0	2026-10-22 03:59:35.903+07	2026-10-22 03:59:35.913313+07
5492	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	184	75	0	2026-10-22 03:59:35.904+07	2026-10-22 03:59:35.915102+07
5493	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	197	75	0	2026-10-22 03:59:35.903+07	2026-10-22 03:59:35.91709+07
5494	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	217	75	0	2026-10-22 03:59:39.416+07	2026-10-22 03:59:39.421329+07
5495	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	251	75	0	2026-10-22 03:59:39.416+07	2026-10-22 03:59:39.423278+07
5496	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	256	75	0	2026-10-22 03:59:39.416+07	2026-10-22 03:59:39.426329+07
5497	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	246	75	0	2026-10-22 03:59:39.416+07	2026-10-22 03:59:39.429765+07
5498	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	221	75	0	2026-10-22 03:59:39.416+07	2026-10-22 03:59:39.43184+07
5499	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	251	75	0	2026-10-22 03:59:42.91+07	2026-10-22 03:59:42.91707+07
5500	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	231	75	0	2026-10-22 03:59:42.91+07	2026-10-22 03:59:42.919638+07
5501	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	221	75	0	2026-10-22 03:59:42.91+07	2026-10-22 03:59:42.921783+07
5502	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	242	75	0	2026-10-22 03:59:42.91+07	2026-10-22 03:59:42.924168+07
5503	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	208	75	0	2026-10-22 03:59:42.91+07	2026-10-22 03:59:42.92647+07
5504	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	243	75	0	2026-10-22 03:59:46.413+07	2026-10-22 03:59:46.423+07
5505	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	217	75	0	2026-10-22 03:59:46.406+07	2026-10-22 03:59:46.427227+07
5506	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	230	75	0	2026-10-22 03:59:46.405+07	2026-10-22 03:59:46.431299+07
5507	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	185	75	0	2026-10-22 03:59:46.405+07	2026-10-22 03:59:46.435329+07
5508	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	252	75	0	2026-10-22 03:59:46.416+07	2026-10-22 03:59:46.439077+07
5539	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	57	0	15.33	2026-10-22 04:00:08.454+07	2026-10-22 04:00:10.922678+07
5540	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	217	75	0	2026-10-22 04:00:10.914+07	2026-10-22 04:00:10.928239+07
5541	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	57	0	17.67	2026-10-22 04:00:08.467+07	2026-10-22 04:00:10.932972+07
5542	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	56	0	17.67	2026-10-22 04:00:08.446+07	2026-10-22 04:00:10.938027+07
5543	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	226	75	0	2026-10-22 04:00:10.913+07	2026-10-22 04:00:10.944035+07
5544	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	230	75	0	2026-10-22 04:00:14.422+07	2026-10-22 04:00:14.429353+07
5545	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	234	75	0	2026-10-22 04:00:14.422+07	2026-10-22 04:00:14.432459+07
5546	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	240	75	0	2026-10-22 04:00:14.421+07	2026-10-22 04:00:14.43488+07
5547	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	223	75	0	2026-10-22 04:00:14.422+07	2026-10-22 04:00:14.436869+07
5548	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	226	75	0	2026-10-22 04:00:14.421+07	2026-10-22 04:00:14.438766+07
5549	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	227	75	0	2026-10-22 04:00:17.915+07	2026-10-22 04:00:17.926757+07
5550	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	220	75	0	2026-10-22 04:00:17.915+07	2026-10-22 04:00:17.932026+07
5551	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	238	75	0	2026-10-22 04:00:17.915+07	2026-10-22 04:00:17.936162+07
5552	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	212	75	0	2026-10-22 04:00:17.914+07	2026-10-22 04:00:17.939456+07
5553	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	216	75	0	2026-10-22 04:00:17.914+07	2026-10-22 04:00:17.942746+07
5554	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	223	75	0	2026-10-22 04:00:21.411+07	2026-10-22 04:00:21.415984+07
5555	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	238	75	0	2026-10-22 04:00:21.408+07	2026-10-22 04:00:21.418048+07
5556	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	256	75	0	2026-10-22 04:00:21.411+07	2026-10-22 04:00:21.420282+07
5557	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	230	75	0	2026-10-22 04:00:21.411+07	2026-10-22 04:00:21.42277+07
5558	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	246	75	0	2026-10-22 04:00:21.408+07	2026-10-22 04:00:21.424736+07
5559	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	222	75	0	2026-10-22 04:00:24.912+07	2026-10-22 04:00:25.411317+07
5560	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 04:00:25.406+07	2026-10-22 04:00:25.413737+07
5561	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	233	75	0	2026-10-22 04:00:24.913+07	2026-10-22 04:00:25.41584+07
5562	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	214	75	0	2026-10-22 04:00:24.912+07	2026-10-22 04:00:25.417891+07
5563	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 04:00:25.406+07	2026-10-22 04:00:25.419892+07
5564	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	119	0	52	2026-10-22 04:00:26.674+07	2026-10-22 04:00:28.914641+07
5565	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	60	0	12.67	2026-10-22 04:00:26.442+07	2026-10-22 04:00:28.917433+07
5566	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	57	0	11.33	2026-10-22 04:00:26.441+07	2026-10-22 04:00:28.921228+07
5567	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	62	0	23.67	2026-10-22 04:00:26.446+07	2026-10-22 04:00:28.924019+07
5568	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	238	75	0	2026-10-22 04:00:28.908+07	2026-10-22 04:00:28.926505+07
5584	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-22 04:02:05.404+07	2026-10-22 04:02:05.412383+07
5585	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	223	75	0	2026-10-22 04:03:07.908+07	2026-10-22 04:03:07.919126+07
5586	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	241	75	0	2026-10-22 04:03:07.908+07	2026-10-22 04:03:07.922926+07
5587	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	232	75	0	2026-10-22 04:03:07.914+07	2026-10-22 04:03:07.92492+07
5588	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	240	75	0	2026-10-22 04:03:07.913+07	2026-10-22 04:03:07.926727+07
5589	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	231	75	0	2026-10-22 04:03:07.914+07	2026-10-22 04:03:07.92848+07
5590	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	250	75	0	2026-10-22 04:03:09.424+07	2026-10-22 04:03:09.433489+07
5591	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	246	75	0	2026-10-22 04:03:09.423+07	2026-10-22 04:03:09.439666+07
5592	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	234	75	0	2026-10-22 04:03:09.424+07	2026-10-22 04:03:09.444793+07
5593	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	238	75	0	2026-10-22 04:03:09.423+07	2026-10-22 04:03:09.449598+07
5594	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	242	75	0	2026-10-22 04:03:09.424+07	2026-10-22 04:03:09.455322+07
5595	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	225	75	0	2026-10-22 04:03:12.909+07	2026-10-22 04:03:12.915185+07
5596	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	214	75	0	2026-10-22 04:03:12.909+07	2026-10-22 04:03:12.91802+07
5597	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	201	75	0	2026-10-22 04:03:12.909+07	2026-10-22 04:03:12.921816+07
5598	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	187	75	0	2026-10-22 04:03:12.909+07	2026-10-22 04:03:12.924765+07
5599	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	236	75	0	2026-10-22 04:03:12.909+07	2026-10-22 04:03:12.926922+07
5610	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	207	75	0	2026-10-22 04:03:23.91+07	2026-10-22 04:03:23.916366+07
5611	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	242	75	0	2026-10-22 04:03:23.91+07	2026-10-22 04:03:23.918759+07
5612	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	254	75	0	2026-10-22 04:03:23.91+07	2026-10-22 04:03:23.921174+07
5613	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	229	75	0	2026-10-22 04:03:23.91+07	2026-10-22 04:03:23.92407+07
5509	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	236	75	0	2026-10-22 03:59:49.912+07	2026-10-22 03:59:49.919827+07
5510	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	246	75	0	2026-10-22 03:59:49.912+07	2026-10-22 03:59:49.923133+07
5511	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	232	75	0	2026-10-22 03:59:49.912+07	2026-10-22 03:59:49.926204+07
5512	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	249	75	0	2026-10-22 03:59:49.912+07	2026-10-22 03:59:49.928934+07
5513	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	240	75	0	2026-10-22 03:59:49.912+07	2026-10-22 03:59:49.931824+07
5514	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	236	75	0	2026-10-22 03:59:53.408+07	2026-10-22 03:59:53.41505+07
5515	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	242	75	0	2026-10-22 03:59:53.409+07	2026-10-22 03:59:53.41715+07
5516	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	253	75	0	2026-10-22 03:59:53.409+07	2026-10-22 03:59:53.419166+07
5517	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	247	75	0	2026-10-22 03:59:53.409+07	2026-10-22 03:59:53.421128+07
5518	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	231	75	0	2026-10-22 03:59:53.409+07	2026-10-22 03:59:53.422877+07
5519	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	249	75	0	2026-10-22 03:59:56.908+07	2026-10-22 03:59:56.914254+07
5520	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	214	75	0	2026-10-22 03:59:56.908+07	2026-10-22 03:59:56.916836+07
5521	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	240	75	0	2026-10-22 03:59:56.908+07	2026-10-22 03:59:56.919177+07
5522	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	244	75	0	2026-10-22 03:59:56.908+07	2026-10-22 03:59:56.921181+07
5523	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	219	75	0	2026-10-22 03:59:56.908+07	2026-10-22 03:59:56.923002+07
5524	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	244	75	0	2026-10-22 04:00:00.416+07	2026-10-22 04:00:00.421301+07
5525	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	234	75	0	2026-10-22 04:00:00.416+07	2026-10-22 04:00:00.423338+07
5526	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	208	75	0	2026-10-22 04:00:00.416+07	2026-10-22 04:00:00.425603+07
5527	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	222	75	0	2026-10-22 04:00:00.416+07	2026-10-22 04:00:00.427936+07
5528	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	254	75	0	2026-10-22 04:00:00.416+07	2026-10-22 04:00:00.43064+07
5529	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	237	75	0	2026-10-22 04:00:03.908+07	2026-10-22 04:00:03.914787+07
5530	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	224	75	0	2026-10-22 04:00:03.908+07	2026-10-22 04:00:03.917491+07
5531	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	228	75	0	2026-10-22 04:00:03.908+07	2026-10-22 04:00:03.920004+07
5532	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	233	75	0	2026-10-22 04:00:03.908+07	2026-10-22 04:00:03.922325+07
5533	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	241	75	0	2026-10-22 04:00:03.908+07	2026-10-22 04:00:03.924867+07
5534	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	253	75	0	2026-10-22 04:00:07.418+07	2026-10-22 04:00:07.423496+07
5535	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	229	75	0	2026-10-22 04:00:07.418+07	2026-10-22 04:00:07.425801+07
5536	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	235	75	0	2026-10-22 04:00:07.418+07	2026-10-22 04:00:07.42815+07
5537	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	245	75	0	2026-10-22 04:00:07.418+07	2026-10-22 04:00:07.430512+07
5538	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	242	75	0	2026-10-22 04:00:07.418+07	2026-10-22 04:00:07.432319+07
5569	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	49	0	15.33	2026-10-22 04:00:29.894+07	2026-10-22 04:00:32.410148+07
5570	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	226	75	0	2026-10-22 04:00:32.404+07	2026-10-22 04:00:32.412205+07
5571	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	221	75	0	2026-10-22 04:00:32.404+07	2026-10-22 04:00:32.414215+07
5572	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	233	75	0	2026-10-22 04:00:32.404+07	2026-10-22 04:00:32.416406+07
5573	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	244	75	0	2026-10-22 04:00:32.405+07	2026-10-22 04:00:32.418596+07
5574	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	194	75	0	2026-10-22 04:00:35.905+07	2026-10-22 04:00:35.909991+07
5575	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	203	75	0	2026-10-22 04:00:35.905+07	2026-10-22 04:00:35.91181+07
5576	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	186	75	0	2026-10-22 04:00:35.905+07	2026-10-22 04:00:35.913676+07
5577	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	223	75	0	2026-10-22 04:00:35.905+07	2026-10-22 04:00:35.915545+07
5578	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	213	75	0	2026-10-22 04:00:35.905+07	2026-10-22 04:00:35.917244+07
5579	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	230	75	0	2026-10-22 04:00:39.416+07	2026-10-22 04:00:39.420565+07
5580	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	230	75	0	2026-10-22 04:00:39.415+07	2026-10-22 04:00:39.422576+07
5581	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	239	75	0	2026-10-22 04:00:39.416+07	2026-10-22 04:00:39.424927+07
5582	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	235	75	0	2026-10-22 04:00:39.416+07	2026-10-22 04:00:39.426993+07
5583	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	243	75	0	2026-10-22 04:00:39.416+07	2026-10-22 04:00:39.428811+07
5600	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	225	75	0	2026-10-22 04:03:16.413+07	2026-10-22 04:03:16.423394+07
5601	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	246	75	0	2026-10-22 04:03:16.413+07	2026-10-22 04:03:16.435123+07
5602	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	212	75	0	2026-10-22 04:03:16.413+07	2026-10-22 04:03:16.43777+07
5603	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	238	75	0	2026-10-22 04:03:16.413+07	2026-10-22 04:03:16.441342+07
5604	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	57	0	19.33	2026-10-22 04:03:13.961+07	2026-10-22 04:03:16.443335+07
5605	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	183	75	0	2026-10-22 04:03:19.913+07	2026-10-22 04:03:20.42617+07
5606	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	718	75	0	2026-10-22 04:03:20.418+07	2026-10-22 04:03:20.429131+07
5607	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	730	75	0	2026-10-22 04:03:20.419+07	2026-10-22 04:03:20.431716+07
5608	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	61	0	25.33	2026-10-22 04:03:17.487+07	2026-10-22 04:03:20.433968+07
5609	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	723	75	0	2026-10-22 04:03:20.418+07	2026-10-22 04:03:20.4363+07
5620	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	247	75	0	2026-10-22 04:03:30.914+07	2026-10-22 04:03:30.919604+07
5621	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	251	75	0	2026-10-22 04:03:30.913+07	2026-10-22 04:03:30.922423+07
5614	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	217	75	0	2026-10-22 04:03:23.91+07	2026-10-22 04:03:23.92603+07
5615	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	238	75	0	2026-10-22 04:03:27.422+07	2026-10-22 04:03:27.433767+07
5616	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	219	75	0	2026-10-22 04:03:27.422+07	2026-10-22 04:03:27.439432+07
5617	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	228	75	0	2026-10-22 04:03:27.422+07	2026-10-22 04:03:27.447339+07
5618	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	193	75	0	2026-10-22 04:03:27.422+07	2026-10-22 04:03:27.453182+07
5619	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	207	75	0	2026-10-22 04:03:27.422+07	2026-10-22 04:03:27.459756+07
5635	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	227	75	0	2026-10-22 04:03:41.407+07	2026-10-22 04:03:41.411839+07
5636	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	234	75	0	2026-10-22 04:03:41.407+07	2026-10-22 04:03:41.413686+07
5637	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	240	75	0	2026-10-22 04:03:41.407+07	2026-10-22 04:03:41.415494+07
5638	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	235	75	0	2026-10-22 04:03:41.407+07	2026-10-22 04:03:41.417973+07
5639	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	223	75	0	2026-10-22 04:03:41.407+07	2026-10-22 04:03:41.420914+07
5659	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	42	0	11.33	2026-10-22 04:04:10.867+07	2026-10-22 04:04:13.923982+07
5660	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	743	75	0	2026-10-22 04:04:13.912+07	2026-10-22 04:04:13.929636+07
5661	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	732	75	0	2026-10-22 04:04:16.413+07	2026-10-22 04:04:16.425269+07
5662	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	742	75	0	2026-10-22 04:04:16.413+07	2026-10-22 04:04:16.431157+07
5711	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	241	75	0	2026-10-22 04:05:47.414+07	2026-10-22 04:05:47.424384+07
5712	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	235	75	0	2026-10-22 04:05:47.414+07	2026-10-22 04:05:47.428569+07
5713	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	238	75	0	2026-10-22 04:05:50.903+07	2026-10-22 04:05:50.908108+07
5714	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	234	75	0	2026-10-22 04:05:50.903+07	2026-10-22 04:05:50.910163+07
5715	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	243	75	0	2026-10-22 04:05:54.41+07	2026-10-22 04:05:54.414832+07
5716	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	240	75	0	2026-10-22 04:05:54.41+07	2026-10-22 04:05:54.417701+07
5717	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	219	75	0	2026-10-22 04:05:57.908+07	2026-10-22 04:05:57.915204+07
5718	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	230	75	0	2026-10-22 04:05:57.907+07	2026-10-22 04:05:57.919519+07
5719	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	239	75	0	2026-10-22 04:06:01.411+07	2026-10-22 04:06:01.419334+07
5720	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	231	75	0	2026-10-22 04:06:01.411+07	2026-10-22 04:06:01.424594+07
5721	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	244	75	0	2026-10-22 04:06:04.913+07	2026-10-22 04:06:04.920741+07
5722	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	233	75	0	2026-10-22 04:06:04.913+07	2026-10-22 04:06:04.924692+07
5731	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	238	75	0	2026-10-22 04:06:22.402+07	2026-10-22 04:06:22.407288+07
5732	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	228	75	0	2026-10-22 04:06:22.402+07	2026-10-22 04:06:22.40927+07
5733	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	233	75	0	2026-10-22 04:06:25.911+07	2026-10-22 04:06:25.917402+07
5734	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	239	75	0	2026-10-22 04:06:25.91+07	2026-10-22 04:06:25.920238+07
5735	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	233	75	0	2026-10-22 04:06:29.408+07	2026-10-22 04:06:29.415382+07
5736	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	244	75	0	2026-10-22 04:06:29.408+07	2026-10-22 04:06:29.419659+07
5737	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	232	75	0	2026-10-22 04:06:32.908+07	2026-10-22 04:06:32.912813+07
5738	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	237	75	0	2026-10-22 04:06:32.908+07	2026-10-22 04:06:32.914645+07
5739	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	230	75	0	2026-10-22 04:06:36.406+07	2026-10-22 04:06:36.411875+07
5740	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	219	75	0	2026-10-22 04:06:36.405+07	2026-10-22 04:06:36.414681+07
5741	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	43	0	14	2026-10-22 04:06:37.363+07	2026-10-22 04:06:39.909905+07
5742	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	243	75	0	2026-10-22 04:06:39.903+07	2026-10-22 04:06:39.912701+07
5743	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	49	0	16.33	2026-10-22 04:06:40.882+07	2026-10-22 04:06:40.891522+07
5744	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	47	0	15.33	2026-10-22 04:06:40.887+07	2026-10-22 04:06:40.893269+07
5622	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	255	75	0	2026-10-22 04:03:30.913+07	2026-10-22 04:03:30.926017+07
5623	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	243	75	0	2026-10-22 04:03:30.913+07	2026-10-22 04:03:30.928531+07
5624	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	238	75	0	2026-10-22 04:03:30.914+07	2026-10-22 04:03:30.93078+07
5625	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	237	75	0	2026-10-22 04:03:34.408+07	2026-10-22 04:03:34.415364+07
5626	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	248	75	0	2026-10-22 04:03:34.408+07	2026-10-22 04:03:34.418172+07
5627	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	226	75	0	2026-10-22 04:03:34.408+07	2026-10-22 04:03:34.420646+07
5628	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	214	75	0	2026-10-22 04:03:34.408+07	2026-10-22 04:03:34.423147+07
5629	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	201	75	0	2026-10-22 04:03:34.405+07	2026-10-22 04:03:34.425571+07
5630	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	239	75	0	2026-10-22 04:03:37.908+07	2026-10-22 04:03:37.916304+07
5631	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	228	75	0	2026-10-22 04:03:37.908+07	2026-10-22 04:03:37.918687+07
5632	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	232	75	0	2026-10-22 04:03:37.908+07	2026-10-22 04:03:37.921291+07
5633	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	218	75	0	2026-10-22 04:03:37.908+07	2026-10-22 04:03:37.923588+07
5634	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	194	75	0	2026-10-22 04:03:37.908+07	2026-10-22 04:03:37.926272+07
5640	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	252	75	0	2026-10-22 04:03:44.91+07	2026-10-22 04:03:44.915723+07
5641	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	248	75	0	2026-10-22 04:03:44.91+07	2026-10-22 04:03:44.918306+07
5642	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	252	75	0	2026-10-22 04:03:44.91+07	2026-10-22 04:03:44.923172+07
5643	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	236	75	0	2026-10-22 04:03:44.91+07	2026-10-22 04:03:44.925657+07
5644	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	241	75	0	2026-10-22 04:03:44.91+07	2026-10-22 04:03:44.92743+07
5645	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	736	75	0	2026-10-22 04:03:45.911+07	2026-10-22 04:03:45.915058+07
5646	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	740	75	0	2026-10-22 04:03:45.911+07	2026-10-22 04:03:45.91671+07
5647	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	738	75	0	2026-10-22 04:03:49.902+07	2026-10-22 04:03:49.908754+07
5648	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	725	75	0	2026-10-22 04:03:49.901+07	2026-10-22 04:03:49.911459+07
5649	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	729	75	0	2026-10-22 04:03:53.909+07	2026-10-22 04:03:53.914602+07
5650	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	734	75	0	2026-10-22 04:03:53.909+07	2026-10-22 04:03:53.916854+07
5651	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	739	75	0	2026-10-22 04:03:57.906+07	2026-10-22 04:03:57.910824+07
5652	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	734	75	0	2026-10-22 04:03:57.906+07	2026-10-22 04:03:57.912677+07
5653	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	739	75	0	2026-10-22 04:04:01.912+07	2026-10-22 04:04:01.916847+07
5654	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	736	75	0	2026-10-22 04:04:01.912+07	2026-10-22 04:04:01.919033+07
5655	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	728	75	0	2026-10-22 04:04:05.907+07	2026-10-22 04:04:05.911979+07
5656	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	733	75	0	2026-10-22 04:04:05.907+07	2026-10-22 04:04:05.913885+07
5657	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	740	75	0	2026-10-22 04:04:09.909+07	2026-10-22 04:04:09.913841+07
5658	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	736	75	0	2026-10-22 04:04:09.909+07	2026-10-22 04:04:09.916079+07
5663	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	736	75	0	2026-10-22 04:04:20.411+07	2026-10-22 04:04:20.422299+07
5664	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	742	75	0	2026-10-22 04:04:20.411+07	2026-10-22 04:04:20.426489+07
5665	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	743	75	0	2026-10-22 04:04:24.406+07	2026-10-22 04:04:24.413415+07
5666	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	738	75	0	2026-10-22 04:04:24.406+07	2026-10-22 04:04:24.417952+07
5667	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	738	75	0	2026-10-22 04:04:28.402+07	2026-10-22 04:04:28.410812+07
5668	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	729	75	0	2026-10-22 04:04:28.402+07	2026-10-22 04:04:28.414559+07
5669	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	743	75	0	2026-10-22 04:04:32.415+07	2026-10-22 04:04:32.427281+07
5670	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	739	75	0	2026-10-22 04:04:32.415+07	2026-10-22 04:04:32.43306+07
5671	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	756	75	0	2026-10-22 04:04:36.417+07	2026-10-22 04:04:36.424805+07
5672	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	743	75	0	2026-10-22 04:04:36.417+07	2026-10-22 04:04:36.427986+07
5673	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	736	75	0	2026-10-22 04:04:40.401+07	2026-10-22 04:04:40.408895+07
5674	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	739	75	0	2026-10-22 04:04:40.401+07	2026-10-22 04:04:40.412194+07
5675	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	52	0	19.33	2026-10-22 04:04:41.402+07	2026-10-22 04:04:44.410308+07
5676	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	740	75	0	2026-10-22 04:04:44.402+07	2026-10-22 04:04:44.414421+07
5677	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	232	75	0	2026-10-22 04:04:47.907+07	2026-10-22 04:04:47.921003+07
5678	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	243	75	0	2026-10-22 04:04:47.906+07	2026-10-22 04:04:47.925796+07
5679	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	41	0	12.33	2026-10-22 04:04:48.878+07	2026-10-22 04:04:51.419265+07
5680	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	240	75	0	2026-10-22 04:04:51.412+07	2026-10-22 04:04:51.423358+07
5681	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	242	75	0	2026-10-22 04:04:54.915+07	2026-10-22 04:04:54.925662+07
5682	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	231	75	0	2026-10-22 04:04:54.915+07	2026-10-22 04:04:54.929223+07
5683	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	238	75	0	2026-10-22 04:04:58.414+07	2026-10-22 04:04:58.42353+07
5684	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	243	75	0	2026-10-22 04:04:58.414+07	2026-10-22 04:04:58.427146+07
5685	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	218	75	0	2026-10-22 04:05:01.908+07	2026-10-22 04:05:01.914507+07
5686	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	231	75	0	2026-10-22 04:05:01.908+07	2026-10-22 04:05:01.916842+07
5687	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	235	75	0	2026-10-22 04:05:05.409+07	2026-10-22 04:05:05.416425+07
5688	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	246	75	0	2026-10-22 04:05:05.408+07	2026-10-22 04:05:05.421154+07
5689	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	232	75	0	2026-10-22 04:05:08.913+07	2026-10-22 04:05:08.920195+07
5690	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	243	75	0	2026-10-22 04:05:08.913+07	2026-10-22 04:05:08.923442+07
5691	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	237	75	0	2026-10-22 04:05:12.408+07	2026-10-22 04:05:12.413641+07
5692	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	244	75	0	2026-10-22 04:05:12.408+07	2026-10-22 04:05:12.415888+07
5693	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	233	75	0	2026-10-22 04:05:15.905+07	2026-10-22 04:05:15.912042+07
5694	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	238	75	0	2026-10-22 04:05:15.905+07	2026-10-22 04:05:15.915445+07
5695	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	242	75	0	2026-10-22 04:05:19.41+07	2026-10-22 04:05:19.416998+07
5696	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	230	75	0	2026-10-22 04:05:19.41+07	2026-10-22 04:05:19.421705+07
5697	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	241	75	0	2026-10-22 04:05:22.911+07	2026-10-22 04:05:22.918124+07
5698	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	230	75	0	2026-10-22 04:05:22.911+07	2026-10-22 04:05:22.921878+07
5699	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	231	75	0	2026-10-22 04:05:26.402+07	2026-10-22 04:05:26.408973+07
5700	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	241	75	0	2026-10-22 04:05:26.402+07	2026-10-22 04:05:26.411794+07
5701	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	233	75	0	2026-10-22 04:05:29.915+07	2026-10-22 04:05:29.919963+07
5702	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	244	75	0	2026-10-22 04:05:29.915+07	2026-10-22 04:05:29.922363+07
5703	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	234	75	0	2026-10-22 04:05:33.407+07	2026-10-22 04:05:33.412917+07
5704	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	243	75	0	2026-10-22 04:05:33.407+07	2026-10-22 04:05:33.415996+07
5705	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	243	75	0	2026-10-22 04:05:36.91+07	2026-10-22 04:05:36.920851+07
5706	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	240	75	0	2026-10-22 04:05:36.909+07	2026-10-22 04:05:36.926772+07
5707	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	243	75	0	2026-10-22 04:05:40.415+07	2026-10-22 04:05:40.422013+07
5708	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	234	75	0	2026-10-22 04:05:40.415+07	2026-10-22 04:05:40.425123+07
5709	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	213	75	0	2026-10-22 04:05:43.906+07	2026-10-22 04:05:43.915395+07
5710	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	224	75	0	2026-10-22 04:05:43.904+07	2026-10-22 04:05:43.922653+07
5723	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	232	75	0	2026-10-22 04:06:08.411+07	2026-10-22 04:06:08.420944+07
5724	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	242	75	0	2026-10-22 04:06:08.412+07	2026-10-22 04:06:08.426766+07
5725	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	236	75	0	2026-10-22 04:06:11.904+07	2026-10-22 04:06:11.909554+07
5726	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	242	75	0	2026-10-22 04:06:11.904+07	2026-10-22 04:06:11.911866+07
5727	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	232	75	0	2026-10-22 04:06:15.417+07	2026-10-22 04:06:15.423414+07
5728	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	239	75	0	2026-10-22 04:06:15.417+07	2026-10-22 04:06:15.42697+07
5729	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	219	75	0	2026-10-22 04:06:18.908+07	2026-10-22 04:06:18.913732+07
5730	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	228	75	0	2026-10-22 04:06:18.908+07	2026-10-22 04:06:18.917454+07
5745	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	243	75	0	2026-10-22 04:06:44.418+07	2026-10-22 04:06:44.431787+07
5746	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	230	75	0	2026-10-22 04:06:44.418+07	2026-10-22 04:06:44.436095+07
5747	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	237	75	0	2026-10-22 04:06:47.912+07	2026-10-22 04:06:47.918767+07
5748	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	245	75	0	2026-10-22 04:06:47.912+07	2026-10-22 04:06:47.921977+07
5749	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	239	75	0	2026-10-22 04:06:51.403+07	2026-10-22 04:06:51.408524+07
5750	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	242	75	0	2026-10-22 04:06:51.402+07	2026-10-22 04:06:51.411161+07
5751	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	238	75	0	2026-10-22 04:06:54.909+07	2026-10-22 04:06:54.913341+07
5752	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	231	75	0	2026-10-22 04:06:54.909+07	2026-10-22 04:06:54.915348+07
5753	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	233	75	0	2026-10-22 04:06:58.409+07	2026-10-22 04:06:58.413136+07
5754	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	241	75	0	2026-10-22 04:06:58.409+07	2026-10-22 04:06:58.415646+07
5755	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	243	75	0	2026-10-22 04:07:01.91+07	2026-10-22 04:07:01.916403+07
5756	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	253	75	0	2026-10-22 04:07:01.91+07	2026-10-22 04:07:01.919582+07
5757	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	238	75	0	2026-10-22 04:07:05.411+07	2026-10-22 04:07:05.421191+07
5758	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	244	75	0	2026-10-22 04:07:05.411+07	2026-10-22 04:07:05.434404+07
5759	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	244	75	0	2026-10-22 04:07:08.912+07	2026-10-22 04:07:08.92043+07
5760	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	234	75	0	2026-10-22 04:07:08.912+07	2026-10-22 04:07:08.924009+07
5761	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	236	75	0	2026-10-22 04:07:12.412+07	2026-10-22 04:07:12.908879+07
5762	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 04:07:12.902+07	2026-10-22 04:07:12.911911+07
5763	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	232	75	0	2026-10-22 04:07:16.41+07	2026-10-22 04:07:16.420928+07
5764	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	242	75	0	2026-10-22 04:07:16.41+07	2026-10-22 04:07:16.424204+07
5765	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 04:07:20.402+07	2026-10-22 04:07:20.40921+07
5766	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	117	0	56	2026-10-22 04:07:17.678+07	2026-10-22 04:07:20.412969+07
5767	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	39	0	4.67	2026-10-22 04:07:21.356+07	2026-10-22 04:07:21.363172+07
5768	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	38	0	3.33	2026-10-22 04:07:21.359+07	2026-10-22 04:07:21.366121+07
5769	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	59	0	19.33	2026-10-22 04:07:22.379+07	2026-10-22 04:07:24.912542+07
5770	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	237	75	0	2026-10-22 04:07:24.906+07	2026-10-22 04:07:24.915554+07
5771	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	49	0	22	2026-10-22 04:07:25.903+07	2026-10-22 04:07:28.41751+07
5772	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	240	75	0	2026-10-22 04:07:28.408+07	2026-10-22 04:07:28.421734+07
5773	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	246	75	0	2026-10-22 04:07:31.911+07	2026-10-22 04:07:31.915837+07
5774	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	235	75	0	2026-10-22 04:07:31.911+07	2026-10-22 04:07:31.918507+07
5775	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	244	75	0	2026-10-22 04:07:35.411+07	2026-10-22 04:07:35.418791+07
5776	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	232	75	0	2026-10-22 04:07:35.411+07	2026-10-22 04:07:35.422269+07
5777	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	230	75	0	2026-10-22 04:07:38.91+07	2026-10-22 04:07:38.917769+07
5778	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	219	75	0	2026-10-22 04:07:38.91+07	2026-10-22 04:07:38.921693+07
5779	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	238	75	0	2026-10-22 04:07:42.406+07	2026-10-22 04:07:42.41667+07
5780	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	244	75	0	2026-10-22 04:07:42.406+07	2026-10-22 04:07:42.421756+07
5781	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	240	75	0	2026-10-22 04:07:45.911+07	2026-10-22 04:07:45.922934+07
5782	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	229	75	0	2026-10-22 04:07:45.91+07	2026-10-22 04:07:45.926983+07
5783	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	216	75	0	2026-10-22 04:07:49.412+07	2026-10-22 04:07:49.417433+07
5784	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	223	75	0	2026-10-22 04:07:49.412+07	2026-10-22 04:07:49.419793+07
5785	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	241	75	0	2026-10-22 04:07:52.909+07	2026-10-22 04:07:52.920324+07
5786	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	753	75	0	2026-10-22 04:08:01.916+07	2026-10-22 04:08:01.93+07
5787	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	234	75	0	2026-10-22 04:09:46.416+07	2026-10-22 04:09:46.429191+07
5788	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	241	75	0	2026-10-22 04:09:46.416+07	2026-10-22 04:09:46.433164+07
5789	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	230	75	0	2026-10-22 04:09:49.9+07	2026-10-22 04:09:49.905005+07
5790	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	241	75	0	2026-10-22 04:09:49.9+07	2026-10-22 04:09:49.906879+07
5791	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	234	75	0	2026-10-22 04:09:53.402+07	2026-10-22 04:09:53.408396+07
5792	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	240	75	0	2026-10-22 04:09:53.402+07	2026-10-22 04:09:53.411923+07
5793	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	240	75	0	2026-10-22 04:09:56.911+07	2026-10-22 04:09:56.916002+07
5794	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	234	75	0	2026-10-22 04:09:56.911+07	2026-10-22 04:09:56.91779+07
5795	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	223	75	0	2026-10-22 04:10:00.408+07	2026-10-22 04:10:00.414977+07
5796	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	227	75	0	2026-10-22 04:10:00.408+07	2026-10-22 04:10:00.418971+07
5797	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	229	75	0	2026-10-22 04:10:03.912+07	2026-10-22 04:10:03.919042+07
5798	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	236	75	0	2026-10-22 04:10:03.912+07	2026-10-22 04:10:03.922752+07
5799	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	237	75	0	2026-10-22 04:10:07.412+07	2026-10-22 04:10:07.417915+07
5800	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	228	75	0	2026-10-22 04:10:07.412+07	2026-10-22 04:10:07.420402+07
5801	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	59	0	16.33	2026-10-22 04:10:08.449+07	2026-10-22 04:10:10.915152+07
5802	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	237	75	0	2026-10-22 04:10:10.91+07	2026-10-22 04:10:10.917048+07
5803	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	224	75	0	2026-10-22 04:10:14.411+07	2026-10-22 04:10:14.418407+07
5804	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	229	75	0	2026-10-22 04:10:14.41+07	2026-10-22 04:10:14.421875+07
5805	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	57	0	11.67	2026-10-22 04:10:15.421+07	2026-10-22 04:10:17.922247+07
5806	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	241	75	0	2026-10-22 04:10:17.915+07	2026-10-22 04:10:17.926036+07
5807	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	233	75	0	2026-10-22 04:10:21.415+07	2026-10-22 04:10:21.42098+07
5808	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	239	75	0	2026-10-22 04:10:21.415+07	2026-10-22 04:10:21.423859+07
5809	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	241	75	0	2026-10-22 04:10:24.905+07	2026-10-22 04:10:24.90962+07
5810	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	233	75	0	2026-10-22 04:10:24.905+07	2026-10-22 04:10:24.913026+07
5811	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	243	75	0	2026-10-22 04:10:28.411+07	2026-10-22 04:10:28.415525+07
5812	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	233	75	0	2026-10-22 04:10:28.411+07	2026-10-22 04:10:28.417686+07
5813	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	234	75	0	2026-10-22 04:10:31.915+07	2026-10-22 04:10:31.920516+07
5814	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	238	75	0	2026-10-22 04:10:31.915+07	2026-10-22 04:10:31.923135+07
5815	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	230	75	0	2026-10-22 04:10:35.413+07	2026-10-22 04:10:35.422003+07
5816	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	226	75	0	2026-10-22 04:10:35.413+07	2026-10-22 04:10:35.428048+07
5817	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	239	75	0	2026-10-22 04:10:38.904+07	2026-10-22 04:10:38.907569+07
5818	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	233	75	0	2026-10-22 04:10:38.904+07	2026-10-22 04:10:38.909926+07
5819	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	231	75	0	2026-10-22 04:10:42.407+07	2026-10-22 04:10:42.414627+07
5820	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	241	75	0	2026-10-22 04:10:42.407+07	2026-10-22 04:10:42.419478+07
5821	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	231	75	0	2026-10-22 04:10:45.918+07	2026-10-22 04:10:45.931171+07
5822	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	243	75	0	2026-10-22 04:10:45.917+07	2026-10-22 04:10:45.935951+07
5823	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	230	75	0	2026-10-22 04:10:49.408+07	2026-10-22 04:10:49.414886+07
5824	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	241	75	0	2026-10-22 04:10:49.408+07	2026-10-22 04:10:49.418751+07
5825	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	242	75	0	2026-10-22 04:10:52.9+07	2026-10-22 04:10:52.903561+07
5826	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	237	75	0	2026-10-22 04:10:52.9+07	2026-10-22 04:10:52.905391+07
5827	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	232	75	0	2026-10-22 04:10:56.415+07	2026-10-22 04:10:56.423419+07
5828	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	245	75	0	2026-10-22 04:10:56.415+07	2026-10-22 04:10:56.428611+07
5829	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	240	75	0	2026-10-22 04:10:59.9+07	2026-10-22 04:10:59.903791+07
5830	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	230	75	0	2026-10-22 04:10:59.899+07	2026-10-22 04:10:59.905909+07
5831	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	231	75	0	2026-10-22 04:11:03.408+07	2026-10-22 04:11:03.421567+07
5832	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	243	75	0	2026-10-22 04:11:03.409+07	2026-10-22 04:11:03.429275+07
5833	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	236	75	0	2026-10-22 04:11:06.913+07	2026-10-22 04:11:06.917085+07
5834	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	243	75	0	2026-10-22 04:11:06.913+07	2026-10-22 04:11:06.918967+07
5835	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	234	75	0	2026-10-22 04:11:10.408+07	2026-10-22 04:11:10.414838+07
5836	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	242	75	0	2026-10-22 04:11:10.408+07	2026-10-22 04:11:10.418234+07
5853	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	250	75	0	2026-10-22 04:11:41.9+07	2026-10-22 04:11:41.905482+07
5854	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	255	75	0	2026-10-22 04:11:41.9+07	2026-10-22 04:11:41.908018+07
5855	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	232	75	0	2026-10-22 04:11:45.406+07	2026-10-22 04:11:45.419732+07
5856	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	237	75	0	2026-10-22 04:11:45.406+07	2026-10-22 04:11:45.425912+07
5857	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	233	75	0	2026-10-22 04:11:48.911+07	2026-10-22 04:11:48.915777+07
5858	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	237	75	0	2026-10-22 04:11:48.911+07	2026-10-22 04:11:48.917489+07
5859	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	239	75	0	2026-10-22 04:11:52.414+07	2026-10-22 04:11:52.419684+07
5860	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	236	75	0	2026-10-22 04:11:52.414+07	2026-10-22 04:11:52.422084+07
5861	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	235	75	0	2026-10-22 04:11:55.911+07	2026-10-22 04:11:55.915878+07
5862	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	239	75	0	2026-10-22 04:11:55.911+07	2026-10-22 04:11:55.917813+07
5863	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	243	75	0	2026-10-22 04:11:59.411+07	2026-10-22 04:11:59.415935+07
5864	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	234	75	0	2026-10-22 04:11:59.411+07	2026-10-22 04:11:59.418069+07
5865	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	239	75	0	2026-10-22 04:12:02.911+07	2026-10-22 04:12:02.916828+07
5866	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	234	75	0	2026-10-22 04:12:02.911+07	2026-10-22 04:12:02.919045+07
5867	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	40	0	9.67	2026-10-22 04:12:03.87+07	2026-10-22 04:12:06.40651+07
5868	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	239	75	0	2026-10-22 04:12:06.401+07	2026-10-22 04:12:06.410559+07
5871	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	238	75	0	2026-10-22 04:12:10.909+07	2026-10-22 04:12:10.913305+07
5872	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	235	75	0	2026-10-22 04:12:10.909+07	2026-10-22 04:12:10.915362+07
5873	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	236	75	0	2026-10-22 04:12:14.411+07	2026-10-22 04:12:14.4154+07
5874	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	241	75	0	2026-10-22 04:12:14.411+07	2026-10-22 04:12:14.417661+07
5875	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	241	75	0	2026-10-22 04:12:17.917+07	2026-10-22 04:12:17.921253+07
5876	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	246	75	0	2026-10-22 04:12:17.917+07	2026-10-22 04:12:17.923116+07
5877	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	240	75	0	2026-10-22 04:12:21.411+07	2026-10-22 04:12:21.419138+07
5878	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	230	75	0	2026-10-22 04:12:21.411+07	2026-10-22 04:12:21.420917+07
5879	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	242	75	0	2026-10-22 04:12:24.913+07	2026-10-22 04:12:24.919095+07
5880	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	239	75	0	2026-10-22 04:12:24.913+07	2026-10-22 04:12:24.921562+07
5881	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	243	75	0	2026-10-22 04:12:28.409+07	2026-10-22 04:12:28.41422+07
5882	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	231	75	0	2026-10-22 04:12:28.409+07	2026-10-22 04:12:28.417271+07
5883	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	234	75	0	2026-10-22 04:12:31.907+07	2026-10-22 04:12:31.91578+07
5884	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	241	75	0	2026-10-22 04:12:31.906+07	2026-10-22 04:12:31.920675+07
5885	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	239	75	0	2026-10-22 04:12:35.406+07	2026-10-22 04:12:35.410367+07
5886	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	236	75	0	2026-10-22 04:12:35.406+07	2026-10-22 04:12:35.412193+07
5887	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	242	75	0	2026-10-22 04:12:38.906+07	2026-10-22 04:12:39.422792+07
5888	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 04:12:39.412+07	2026-10-22 04:12:39.427871+07
5891	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 04:12:46.909+07	2026-10-22 04:12:46.91314+07
5892	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	129	0	36	2026-10-22 04:12:44.225+07	2026-10-22 04:12:46.914905+07
5893	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	43	0	7	2026-10-22 04:12:47.871+07	2026-10-22 04:12:47.8755+07
5894	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	41	0	4.33	2026-10-22 04:12:47.866+07	2026-10-22 04:12:47.877246+07
5895	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	47	0	17	2026-10-22 04:12:48.842+07	2026-10-22 04:12:51.416639+07
5896	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	239	75	0	2026-10-22 04:12:51.413+07	2026-10-22 04:12:51.418466+07
5897	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	41	0	14.33	2026-10-22 04:12:52.361+07	2026-10-22 04:12:54.91331+07
5898	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	241	75	0	2026-10-22 04:12:54.904+07	2026-10-22 04:12:54.916907+07
5899	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	243	75	0	2026-10-22 04:12:58.417+07	2026-10-22 04:12:58.426818+07
5900	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	231	75	0	2026-10-22 04:12:58.417+07	2026-10-22 04:12:58.430614+07
5907	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	234	75	0	2026-10-22 04:13:12.408+07	2026-10-22 04:13:12.41213+07
5908	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	237	75	0	2026-10-22 04:13:12.408+07	2026-10-22 04:13:12.414065+07
5909	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	228	75	0	2026-10-22 04:13:15.917+07	2026-10-22 04:13:15.921077+07
5910	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	238	75	0	2026-10-22 04:13:15.917+07	2026-10-22 04:13:15.922911+07
5911	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	242	75	0	2026-10-22 04:13:19.405+07	2026-10-22 04:13:19.409281+07
5837	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	240	75	0	2026-10-22 04:11:13.915+07	2026-10-22 04:11:13.9226+07
5838	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	230	75	0	2026-10-22 04:11:13.915+07	2026-10-22 04:11:13.929047+07
5839	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	233	75	0	2026-10-22 04:11:17.407+07	2026-10-22 04:11:17.412065+07
5840	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	243	75	0	2026-10-22 04:11:17.407+07	2026-10-22 04:11:17.414872+07
5841	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	217	75	0	2026-10-22 04:11:20.905+07	2026-10-22 04:11:20.911191+07
5842	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	224	75	0	2026-10-22 04:11:20.905+07	2026-10-22 04:11:20.913899+07
5843	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	234	75	0	2026-10-22 04:11:24.4+07	2026-10-22 04:11:24.404758+07
5844	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	238	75	0	2026-10-22 04:11:24.4+07	2026-10-22 04:11:24.406684+07
5845	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	237	75	0	2026-10-22 04:11:27.912+07	2026-10-22 04:11:27.917268+07
5846	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	232	75	0	2026-10-22 04:11:27.912+07	2026-10-22 04:11:27.919157+07
5847	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	241	75	0	2026-10-22 04:11:31.406+07	2026-10-22 04:11:31.416249+07
5848	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	235	75	0	2026-10-22 04:11:31.406+07	2026-10-22 04:11:31.421511+07
5849	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	240	75	0	2026-10-22 04:11:34.914+07	2026-10-22 04:11:34.920939+07
5850	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	244	75	0	2026-10-22 04:11:34.914+07	2026-10-22 04:11:34.92585+07
5851	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	240	75	0	2026-10-22 04:11:38.404+07	2026-10-22 04:11:38.411529+07
5852	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	237	75	0	2026-10-22 04:11:38.405+07	2026-10-22 04:11:38.415217+07
5869	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	48	0	19	2026-10-22 04:12:07.39+07	2026-10-22 04:12:07.397029+07
5870	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	47	0	14.33	2026-10-22 04:12:07.39+07	2026-10-22 04:12:07.40046+07
5889	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	237	75	0	2026-10-22 04:12:42.912+07	2026-10-22 04:12:42.920817+07
5890	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	231	75	0	2026-10-22 04:12:42.912+07	2026-10-22 04:12:42.923989+07
5901	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	240	75	0	2026-10-22 04:13:01.909+07	2026-10-22 04:13:01.913524+07
5902	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	236	75	0	2026-10-22 04:13:01.909+07	2026-10-22 04:13:01.915205+07
5903	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	229	75	0	2026-10-22 04:13:05.409+07	2026-10-22 04:13:05.419504+07
5904	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	241	75	0	2026-10-22 04:13:05.409+07	2026-10-22 04:13:05.423477+07
5905	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	231	75	0	2026-10-22 04:13:08.901+07	2026-10-22 04:13:08.90732+07
5906	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	241	75	0	2026-10-22 04:13:08.901+07	2026-10-22 04:13:08.910265+07
5912	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	237	75	0	2026-10-22 04:16:50.408+07	2026-10-22 04:16:50.423641+07
5913	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	236	75	0	2026-10-22 04:20:20.901+07	2026-10-22 04:20:20.907443+07
5914	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-22 04:23:51.906+07	2026-10-22 04:23:51.916325+07
5915	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	239	75	0	2026-10-22 04:27:22.912+07	2026-10-22 04:27:22.918353+07
5916	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	241	75	0	2026-10-22 04:30:53.912+07	2026-10-22 04:30:53.919162+07
5917	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	257	75	0	2026-10-22 04:31:07.913+07	2026-10-22 04:31:07.920805+07
5918	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	253	75	0	2026-10-22 04:31:07.913+07	2026-10-22 04:31:07.923274+07
5919	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	725	75	0	2026-10-22 04:31:11.403+07	2026-10-22 04:31:11.411267+07
5920	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-110	192.168.1.159	offline	721	75	0	2026-10-22 04:31:11.403+07	2026-10-22 04:31:11.416054+07
5921	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-13	192.168.1.158	offline	745	75	0	2026-10-22 04:31:15.41+07	2026-10-22 04:31:15.417622+07
5922	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-20	192.168.1.157	offline	739	75	0	2026-10-22 04:31:15.41+07	2026-10-22 04:31:15.421068+07
5923	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-2	192.168.1.156	offline	757	75	0	2026-10-22 04:31:19.419+07	2026-10-22 04:31:19.425047+07
5924	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-38	192.168.1.155	offline	753	75	0	2026-10-22 04:31:19.419+07	2026-10-22 04:31:19.428466+07
5925	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-35	192.168.1.161	offline	743	75	0	2026-10-22 04:31:23.41+07	2026-10-22 04:31:23.417018+07
5926	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-33	192.168.1.126	offline	739	75	0	2026-10-22 04:31:23.409+07	2026-10-22 04:31:23.421207+07
5927	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-31	192.168.1.125	offline	737	75	0	2026-10-22 04:31:27.404+07	2026-10-22 04:31:27.412321+07
5928	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-89	192.168.1.124	offline	236	75	0	2026-10-22 04:31:26.904+07	2026-10-22 04:31:27.416984+07
5929	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-34	192.168.1.123	offline	217	75	0	2026-10-22 04:31:30.913+07	2026-10-22 04:31:30.918055+07
5930	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-93	192.168.1.122	offline	221	75	0	2026-10-22 04:31:30.913+07	2026-10-22 04:31:30.920603+07
5931	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-32	192.168.1.121	offline	238	75	0	2026-10-22 04:31:34.409+07	2026-10-22 04:31:34.415927+07
5932	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-18	192.168.1.120	offline	227	75	0	2026-10-22 04:31:34.409+07	2026-10-22 04:31:34.418966+07
5933	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-1	192.168.1.160	online	58	0	7	2026-10-22 04:31:35.439+07	2026-10-22 04:31:37.920932+07
5934	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-108	192.168.1.118	offline	241	75	0	2026-10-22 04:31:37.91+07	2026-10-22 04:31:37.92675+07
5935	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-42	192.168.1.117	offline	242	75	0	2026-10-22 04:31:41.413+07	2026-10-22 04:31:41.420765+07
5936	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-62	192.168.1.116	offline	230	75	0	2026-10-22 04:31:41.413+07	2026-10-22 04:31:41.424824+07
5937	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-69	192.168.1.1	online	66	0	24.33	2026-10-22 04:31:42.482+07	2026-10-22 04:31:44.917341+07
5938	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-59	192.168.1.114	offline	243	75	0	2026-10-22 04:31:44.906+07	2026-10-22 04:31:44.923025+07
5939	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-64	192.168.1.113	offline	235	75	0	2026-10-22 04:31:48.405+07	2026-10-22 04:31:48.418389+07
5940	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-27	192.168.1.112	offline	246	75	0	2026-10-22 04:31:48.405+07	2026-10-22 04:31:48.422779+07
5941	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-107	192.168.1.111	offline	242	75	0	2026-10-22 04:31:51.911+07	2026-10-22 04:31:51.919313+07
5942	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-97	192.168.1.110	offline	238	75	0	2026-10-22 04:31:51.911+07	2026-10-22 04:31:51.923448+07
5943	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-106	192.168.1.109	offline	228	75	0	2026-10-22 04:31:55.408+07	2026-10-22 04:31:55.415605+07
5944	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-75	192.168.1.108	offline	241	75	0	2026-10-22 04:31:55.408+07	2026-10-22 04:31:55.420151+07
5945	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-92	192.168.1.107	offline	234	75	0	2026-10-22 04:31:58.919+07	2026-10-22 04:31:58.928854+07
5946	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-70	192.168.1.106	offline	243	75	0	2026-10-22 04:31:58.919+07	2026-10-22 04:31:58.934529+07
5947	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-83	192.168.1.105	offline	241	75	0	2026-10-22 04:32:02.403+07	2026-10-22 04:32:02.407344+07
5948	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-63	192.168.1.104	offline	230	75	0	2026-10-22 04:32:02.403+07	2026-10-22 04:32:02.409157+07
5949	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-68	192.168.1.103	offline	245	75	0	2026-10-22 04:32:05.909+07	2026-10-22 04:32:05.914232+07
5950	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-78	192.168.1.102	offline	243	75	0	2026-10-22 04:32:05.909+07	2026-10-22 04:32:05.9171+07
5951	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-14	192.168.1.101	offline	245	75	0	2026-10-22 04:32:09.404+07	2026-10-22 04:32:09.413356+07
5952	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-96	192.168.1.100	offline	233	75	0	2026-10-22 04:32:09.404+07	2026-10-22 04:32:09.417454+07
5953	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-86	192.168.1.99	offline	244	75	0	2026-10-22 04:32:12.919+07	2026-10-22 04:32:12.928976+07
5954	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-94	192.168.1.98	offline	239	75	0	2026-10-22 04:32:12.919+07	2026-10-22 04:32:12.934019+07
5955	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-91	192.168.1.97	offline	242	75	0	2026-10-22 04:32:16.409+07	2026-10-22 04:32:16.416156+07
5956	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-11	192.168.1.96	offline	232	75	0	2026-10-22 04:32:16.409+07	2026-10-22 04:32:16.420019+07
5957	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-85	192.168.1.95	offline	241	75	0	2026-10-22 04:32:19.903+07	2026-10-22 04:32:19.910543+07
5958	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-41	192.168.1.94	offline	245	75	0	2026-10-22 04:32:19.903+07	2026-10-22 04:32:19.914356+07
5959	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-17	192.168.1.93	offline	243	75	0	2026-10-22 04:32:23.42+07	2026-10-22 04:32:23.431904+07
5960	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-6	192.168.1.92	offline	233	75	0	2026-10-22 04:32:23.419+07	2026-10-22 04:32:23.438346+07
5961	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-15	192.168.1.91	offline	227	75	0	2026-10-22 04:32:26.91+07	2026-10-22 04:32:26.91682+07
5962	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-49	192.168.1.90	offline	220	75	0	2026-10-22 04:32:26.91+07	2026-10-22 04:32:26.920529+07
5963	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-104	192.168.1.89	offline	241	75	0	2026-10-22 04:32:30.42+07	2026-10-22 04:32:30.430953+07
5964	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-16	192.168.1.87	offline	229	75	0	2026-10-22 04:32:30.42+07	2026-10-22 04:32:30.437167+07
5965	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-60	192.168.1.86	offline	224	75	0	2026-10-22 04:32:33.917+07	2026-10-22 04:32:33.923326+07
5966	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-48	192.168.1.85	offline	228	75	0	2026-10-22 04:32:33.917+07	2026-10-22 04:32:33.926591+07
5967	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-10	192.168.1.84	offline	226	75	0	2026-10-22 04:32:37.404+07	2026-10-22 04:32:37.408882+07
5968	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-72	192.168.1.83	offline	238	75	0	2026-10-22 04:32:37.404+07	2026-10-22 04:32:37.411819+07
5969	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-74	192.168.1.82	offline	238	75	0	2026-10-22 04:32:40.904+07	2026-10-22 04:32:40.911917+07
5970	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-9	192.168.1.81	offline	242	75	0	2026-10-22 04:32:40.904+07	2026-10-22 04:32:40.916407+07
5971	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-8	192.168.1.80	offline	239	75	0	2026-10-22 04:32:44.415+07	2026-10-22 04:32:44.426138+07
5972	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-103	192.168.1.79	offline	228	75	0	2026-10-22 04:32:44.415+07	2026-10-22 04:32:44.430835+07
5973	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-52	192.168.1.78	offline	227	75	0	2026-10-22 04:32:47.905+07	2026-10-22 04:32:47.910789+07
5974	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-44	192.168.1.77	offline	223	75	0	2026-10-22 04:32:47.905+07	2026-10-22 04:32:47.914406+07
5975	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-95	192.168.1.76	offline	230	75	0	2026-10-22 04:32:51.401+07	2026-10-22 04:32:51.405406+07
5976	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-12	192.168.1.75	offline	219	75	0	2026-10-22 04:32:51.401+07	2026-10-22 04:32:51.407567+07
5977	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-54	192.168.1.74	offline	242	75	0	2026-10-22 04:32:54.908+07	2026-10-22 04:32:54.913876+07
5978	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-5	192.168.1.73	offline	238	75	0	2026-10-22 04:32:54.908+07	2026-10-22 04:32:54.917793+07
5979	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-114	192.168.1.72	offline	244	75	0	2026-10-22 04:32:58.411+07	2026-10-22 04:32:58.41561+07
5980	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-19	192.168.1.71	offline	195	75	0	2026-10-22 04:32:58.411+07	2026-10-22 04:32:58.41763+07
5981	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-61	192.168.1.70	offline	237	75	0	2026-10-22 04:33:01.914+07	2026-10-22 04:33:01.920955+07
5982	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-90	192.168.1.69	offline	240	75	0	2026-10-22 04:33:01.914+07	2026-10-22 04:33:01.92419+07
5983	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-73	192.168.1.68	offline	242	75	0	2026-10-22 04:33:05.403+07	2026-10-22 04:33:05.406614+07
5984	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-67	192.168.1.67	offline	202	75	0	2026-10-22 04:33:05.403+07	2026-10-22 04:33:05.408505+07
5985	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-76	192.168.1.66	offline	240	75	0	2026-10-22 04:33:08.903+07	2026-10-22 04:33:08.907527+07
5986	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-50	192.168.1.65	offline	237	75	0	2026-10-22 04:33:08.903+07	2026-10-22 04:33:08.909735+07
5987	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-81	192.168.1.64	offline	245	75	0	2026-10-22 04:33:12.413+07	2026-10-22 04:33:12.418155+07
5988	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-39	192.168.1.63	offline	199	75	0	2026-10-22 04:33:12.413+07	2026-10-22 04:33:12.420268+07
5989	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-84	192.168.1.62	offline	259	75	0	2026-10-22 04:33:15.906+07	2026-10-22 04:33:15.914188+07
5990	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-29	192.168.1.61	offline	253	75	0	2026-10-22 04:33:15.905+07	2026-10-22 04:33:15.918307+07
5991	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-53	192.168.1.60	offline	244	75	0	2026-10-22 04:33:19.415+07	2026-10-22 04:33:19.431022+07
5992	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-43	192.168.1.59	offline	234	75	0	2026-10-22 04:33:19.415+07	2026-10-22 04:33:19.434718+07
5993	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-100	192.168.1.58	offline	238	75	0	2026-10-22 04:33:22.91+07	2026-10-22 04:33:22.915191+07
5994	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-57	192.168.1.57	offline	234	75	0	2026-10-22 04:33:22.91+07	2026-10-22 04:33:22.916967+07
5995	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-109	192.168.1.56	offline	244	75	0	2026-10-22 04:33:26.406+07	2026-10-22 04:33:26.417087+07
5996	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-45	192.168.1.55	offline	233	75	0	2026-10-22 04:33:26.406+07	2026-10-22 04:33:26.419689+07
5997	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-55	192.168.1.54	offline	227	75	0	2026-10-22 04:33:29.907+07	2026-10-22 04:33:29.911836+07
5998	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-3	192.168.1.53	offline	234	75	0	2026-10-22 04:33:29.907+07	2026-10-22 04:33:29.91382+07
5999	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-111	192.168.1.52	online	56	0	14.33	2026-10-22 04:33:30.917+07	2026-10-22 04:33:33.409152+07
6000	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-36	192.168.1.51	offline	238	75	0	2026-10-22 04:33:33.404+07	2026-10-22 04:33:33.412353+07
6001	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-47	192.168.1.50	online	45	0	13	2026-10-22 04:33:34.38+07	2026-10-22 04:33:34.384092+07
6002	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-77	192.168.1.49	online	42	0	10	2026-10-22 04:33:34.368+07	2026-10-22 04:33:34.385862+07
6003	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-99	192.168.1.48	offline	229	75	0	2026-10-22 04:33:37.901+07	2026-10-22 04:33:37.906914+07
6004	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-26	192.168.1.47	offline	226	75	0	2026-10-22 04:33:37.901+07	2026-10-22 04:33:37.909815+07
6005	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-112	192.168.1.46	offline	243	75	0	2026-10-22 04:33:41.413+07	2026-10-22 04:33:41.417874+07
6006	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-65	192.168.1.45	offline	233	75	0	2026-10-22 04:33:41.413+07	2026-10-22 04:33:41.420013+07
6007	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-113	192.168.1.44	offline	243	75	0	2026-10-22 04:33:44.908+07	2026-10-22 04:33:44.912943+07
6008	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-88	192.168.1.43	offline	239	75	0	2026-10-22 04:33:44.908+07	2026-10-22 04:33:44.915207+07
6011	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-82	192.168.1.40	offline	235	75	0	2026-10-22 04:33:51.904+07	2026-10-22 04:33:51.911277+07
6012	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-51	192.168.1.39	offline	239	75	0	2026-10-22 04:33:51.904+07	2026-10-22 04:33:51.914411+07
6013	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-24	192.168.1.38	offline	238	75	0	2026-10-22 04:33:55.414+07	2026-10-22 04:33:55.425178+07
6014	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-25	192.168.1.37	offline	231	75	0	2026-10-22 04:33:55.414+07	2026-10-22 04:33:55.430447+07
6017	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-58	192.168.1.14	offline	241	75	0	2026-10-22 04:34:02.4+07	2026-10-22 04:34:02.404969+07
6018	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-105	192.168.1.13	offline	229	75	0	2026-10-22 04:34:02.4+07	2026-10-22 04:34:02.406894+07
6009	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-102	192.168.1.42	offline	239	75	0	2026-10-22 04:33:48.415+07	2026-10-22 04:33:48.425119+07
6010	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-7	192.168.1.41	offline	242	75	0	2026-10-22 04:33:48.415+07	2026-10-22 04:33:48.429444+07
6015	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-56	192.168.1.36	offline	237	75	0	2026-10-22 04:33:58.902+07	2026-10-22 04:33:58.908957+07
6016	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-87	192.168.1.15	offline	234	75	0	2026-10-22 04:33:58.902+07	2026-10-22 04:33:58.91141+07
6019	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-101	192.168.1.12	offline	243	75	0	2026-10-22 04:34:05.91+07	2026-10-22 04:34:06.415838+07
6020	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	offline	\N	100	0	2026-10-22 04:34:06.411+07	2026-10-22 04:34:06.417943+07
6021	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-98	192.168.1.10	offline	235	75	0	2026-10-22 04:34:09.907+07	2026-10-22 04:34:09.918507+07
6022	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-66	192.168.1.9	offline	231	75	0	2026-10-22 04:34:09.906+07	2026-10-22 04:34:09.924675+07
6023	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-80	192.168.1.8	offline	\N	100	0	2026-10-22 04:34:13.907+07	2026-10-22 04:34:13.914315+07
6024	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-4	192.168.1.7	online	92	0	45.33	2026-10-22 04:34:11.067+07	2026-10-22 04:34:13.91643+07
6025	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-30	192.168.1.6	online	36	0	3	2026-10-22 04:34:14.848+07	2026-10-22 04:34:14.855385+07
6026	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-21	192.168.1.5	online	33	0	2.33	2026-10-22 04:34:14.851+07	2026-10-22 04:34:14.857186+07
6027	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-28	192.168.1.4	online	49	0	8.67	2026-10-22 04:34:15.817+07	2026-10-22 04:34:18.40432+07
6028	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-23	192.168.1.3	offline	240	75	0	2026-10-22 04:34:18.399+07	2026-10-22 04:34:18.406797+07
6029	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-46	192.168.1.2	online	37	0	14	2026-10-22 04:34:19.326+07	2026-10-22 04:34:21.921156+07
6030	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-22	192.168.1.135	offline	237	75	0	2026-10-22 04:34:21.915+07	2026-10-22 04:34:21.923871+07
6031	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-37	192.168.1.0	offline	244	75	0	2026-10-22 04:34:25.401+07	2026-10-22 04:34:25.406124+07
6032	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-40	192.168.1.16	offline	254	75	0	2026-10-22 04:34:25.402+07	2026-10-22 04:34:25.407982+07
6033	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-khoa-hoc-va-cong-nghe	192.168.1.170	offline	242	75	0	2026-10-22 04:34:28.906+07	2026-10-22 04:34:28.916773+07
6034	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-van-hoa-va-du-lich	192.168.1.171	offline	238	75	0	2026-10-22 04:34:28.906+07	2026-10-22 04:34:28.919506+07
6035	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-nong-nghiep-va-moi-truong	192.168.1.172	offline	232	75	0	2026-10-22 04:34:32.412+07	2026-10-22 04:34:32.420714+07
6036	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-tai-chinh	192.168.1.173	offline	238	75	0	2026-10-22 04:34:32.412+07	2026-10-22 04:34:32.424588+07
6037	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-cong-thuong	192.168.1.174	offline	242	75	0	2026-10-22 04:34:35.915+07	2026-10-22 04:34:35.91891+07
6038	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-ngoai-vu	192.168.1.175	offline	236	75	0	2026-10-22 04:34:35.915+07	2026-10-22 04:34:35.920721+07
6039	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-noi-vu	192.168.1.176	offline	236	75	0	2026-10-22 04:34:39.415+07	2026-10-22 04:34:39.426561+07
6040	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-y-te	192.168.1.177	offline	244	75	0	2026-10-22 04:34:39.415+07	2026-10-22 04:34:39.431749+07
6041	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-so-giao-duc-va-dao-tao	192.168.1.178	offline	239	75	0	2026-10-22 04:34:42.919+07	2026-10-22 04:34:42.930701+07
6042	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-ban-quan-ly-cac-kkt	192.168.1.179	offline	245	75	0	2026-10-22 04:34:42.919+07	2026-10-22 04:34:42.939017+07
6043	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-extra-vuon-quoc-gia-cat-ba	192.168.1.180	offline	237	75	0	2026-10-22 04:34:46.399+07	2026-10-22 04:34:46.415459+07
6044	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	234	75	0	2026-10-22 04:38:17.404+07	2026-10-22 04:38:17.415187+07
6045	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-hub	192.168.1.169	offline	240	75	0	2026-10-22 04:41:48.408+07	2026-10-22 04:41:48.417159+07
6046	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	hnth-branch-79	192.168.1.11	online	102	0	44.33	2026-10-22 04:44:37.105+07	2026-10-22 04:44:39.42687+07
\.


--
-- Data for Name: monitor_state; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.monitor_state (id, enabled, agent_id, concurrency, wait_seconds, session_id, started_at, updated_at, revision, lease_expires_at, active_roster_id) FROM stdin;
1	t	agent-508b0be9-fed3-4271-8a1f-805bf50fe2da	2	3	52270726-b365-4064-b4e6-0443f67e511c	2026-10-22 04:31:06.446917+07	2026-10-22 04:31:06.446917+07	125	2026-10-22 04:47:00.904018+07	\N
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schema_migrations (version, name, applied_at) FROM stdin;
1	baseline	2026-10-21 17:40:11.621748+07
2	monitor-lease	2026-10-21 18:33:27.578546+07
3	hnth-rosters	2026-10-22 02:29:35.899813+07
4	hnth-catalog	2026-10-22 02:50:00.152618+07
\.


--
-- Data for Name: snmp_results; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.snmp_results (id, agent_id, target_id, host, oid, value, value_type, checked_at, received_at) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, username, password_hash, display_name, role, menu_permissions, is_active, created_at, updated_at, department, phone) FROM stdin;
529aaa52-59df-48eb-94bf-8a96a7e1b1b3	admin	$2b$12$aedtYYhpc4oHUlr.GNtk7uZ3YQjmkfzcRxu5p80aOE2VKeHKAekrS	HNTH Administrator	admin	["layers", "zones", "saved", "routing", "conference", "agents"]	t	2026-10-21 00:19:29.630275+07	2026-10-21 00:19:29.630275+07		
\.


--
-- Name: agent_update_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.agent_update_events_id_seq', 6, true);


--
-- Name: audit_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.audit_logs_id_seq', 7, true);


--
-- Name: monitor_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.monitor_logs_id_seq', 6046, true);


--
-- Name: snmp_results_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.snmp_results_id_seq', 1, false);


--
-- Name: agent_releases agent_releases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_releases
    ADD CONSTRAINT agent_releases_pkey PRIMARY KEY (id);


--
-- Name: agent_releases agent_releases_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_releases
    ADD CONSTRAINT agent_releases_version_key UNIQUE (version);


--
-- Name: agent_update_events agent_update_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_update_events
    ADD CONSTRAINT agent_update_events_pkey PRIMARY KEY (id);


--
-- Name: agents agents_agent_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_agent_id_key UNIQUE (agent_id);


--
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: commands commands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commands
    ADD CONSTRAINT commands_pkey PRIMARY KEY (id);


--
-- Name: discovered_ips discovered_ips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discovered_ips
    ADD CONSTRAINT discovered_ips_pkey PRIMARY KEY (agent_id, ip_address);


--
-- Name: endpoints endpoints_endpoint_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endpoints
    ADD CONSTRAINT endpoints_endpoint_id_key UNIQUE (endpoint_id);


--
-- Name: endpoints endpoints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.endpoints
    ADD CONSTRAINT endpoints_pkey PRIMARY KEY (id);


--
-- Name: hnth_catalog hnth_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hnth_catalog
    ADD CONSTRAINT hnth_catalog_pkey PRIMARY KEY (id);


--
-- Name: hnth_rosters hnth_rosters_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hnth_rosters
    ADD CONSTRAINT hnth_rosters_name_key UNIQUE (name);


--
-- Name: hnth_rosters hnth_rosters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hnth_rosters
    ADD CONSTRAINT hnth_rosters_pkey PRIMARY KEY (id);


--
-- Name: monitor_logs monitor_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monitor_logs
    ADD CONSTRAINT monitor_logs_pkey PRIMARY KEY (id);


--
-- Name: monitor_state monitor_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monitor_state
    ADD CONSTRAINT monitor_state_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: snmp_results snmp_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.snmp_results
    ADD CONSTRAINT snmp_results_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: agents_installation_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX agents_installation_id_key ON public.agents USING btree (installation_id) WHERE (installation_id IS NOT NULL);


--
-- Name: agent_releases agent_releases_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_releases
    ADD CONSTRAINT agent_releases_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: hnth_rosters hnth_rosters_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hnth_rosters
    ADD CONSTRAINT hnth_rosters_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: monitor_state monitor_state_active_roster_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.monitor_state
    ADD CONSTRAINT monitor_state_active_roster_id_fkey FOREIGN KEY (active_roster_id) REFERENCES public.hnth_rosters(id) ON DELETE SET NULL;


--
-- Name: refresh_tokens refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict QJFbsV4GcSdO9WukBvsQOydZnpcLd0XRUvSaTaggTv1IQrGqPQne2oEcx4LtNUr

