--
-- PostgreSQL database dump
--


-- Dumped from database version 16.14
-- Dumped by pg_dump version 16.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: dtest2; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA dtest2;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.accounts (
    account_id text NOT NULL,
    role text NOT NULL,
    password_hash text NOT NULL,
    salt text NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    failed_login_count integer DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT accounts_failed_login_count_check CHECK ((failed_login_count >= 0)),
    CONSTRAINT accounts_role_check CHECK ((role = ANY (ARRAY['student'::text, 'admin'::text]))),
    CONSTRAINT accounts_status_check CHECK ((status = ANY (ARRAY['active'::text, 'locked'::text, 'pending'::text, 'disabled'::text])))
);


--
-- Name: admin_profiles; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.admin_profiles (
    admin_id text NOT NULL,
    name text NOT NULL,
    department text NOT NULL,
    role_id text NOT NULL,
    avatar_url text,
    online_status text DEFAULT 'offline'::text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT admin_profiles_online_status_check CHECK ((online_status = ANY (ARRAY['online'::text, 'busy'::text, 'offline'::text])))
);


--
-- Name: app_settings; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.app_settings (
    account_id text NOT NULL,
    key text NOT NULL,
    value_json jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: approval_flow_nodes; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.approval_flow_nodes (
    node_id text NOT NULL,
    name text NOT NULL,
    approver_role text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    node_order integer NOT NULL,
    CONSTRAINT approval_flow_nodes_node_order_check CHECK ((node_order >= 1))
);


--
-- Name: approval_instances; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.approval_instances (
    approval_id text NOT NULL,
    biz_type text NOT NULL,
    biz_id text NOT NULL,
    applicant_id text NOT NULL,
    applicant_name text NOT NULL,
    title text NOT NULL,
    reason text,
    status text DEFAULT 'pending'::text NOT NULL,
    is_urgent boolean DEFAULT false NOT NULL,
    current_step integer DEFAULT 1 NOT NULL,
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT approval_instances_current_step_check CHECK ((current_step >= 1)),
    CONSTRAINT approval_instances_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'withdrawn'::text])))
);


--
-- Name: approval_steps; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.approval_steps (
    step_id text NOT NULL,
    approval_id text NOT NULL,
    step_order integer NOT NULL,
    node_name text NOT NULL,
    approver_role text NOT NULL,
    operator_id text,
    status text DEFAULT 'waiting'::text NOT NULL,
    handled_at timestamp with time zone,
    comment text,
    CONSTRAINT approval_steps_status_check CHECK ((status = ANY (ARRAY['waiting'::text, 'pending'::text, 'approved'::text, 'rejected'::text]))),
    CONSTRAINT approval_steps_step_order_check CHECK ((step_order >= 1))
);


--
-- Name: attachments; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.attachments (
    attachment_id text NOT NULL,
    owner_type text NOT NULL,
    owner_id text NOT NULL,
    file_name text NOT NULL,
    file_url text NOT NULL,
    file_size bigint,
    uploaded_by text,
    uploaded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT attachments_file_size_check CHECK (((file_size IS NULL) OR (file_size >= 0)))
);


--
-- Name: audit_logs; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.audit_logs (
    log_id text NOT NULL,
    operator_id text,
    operator_name text,
    action text NOT NULL,
    action_type text NOT NULL,
    target text NOT NULL,
    result text NOT NULL,
    ip text,
    detail_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT audit_logs_result_check CHECK ((result = ANY (ARRAY['success'::text, 'failed'::text])))
);


--
-- Name: calendar_events; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.calendar_events (
    event_id text NOT NULL,
    event_date date NOT NULL,
    title text NOT NULL,
    type text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT calendar_events_type_check CHECK ((type = ANY (ARRAY['term'::text, 'exam'::text, 'holiday'::text, 'selection'::text, 'makeup'::text, 'other'::text])))
);


--
-- Name: courses; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.courses (
    course_id text NOT NULL,
    code text NOT NULL,
    teaching_class_no text,
    name text NOT NULL,
    category text NOT NULL,
    credit numeric(4,1) NOT NULL,
    teacher text NOT NULL,
    college text,
    campus text,
    classroom text,
    weeks_text text,
    weekday integer,
    period_start integer,
    period_end integer,
    capacity integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    description text,
    assessment_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT courses_capacity_check CHECK ((capacity >= 0)),
    CONSTRAINT courses_category_check CHECK ((category = ANY (ARRAY['required'::text, 'elective'::text, 'public'::text, 'practice'::text]))),
    CONSTRAINT courses_check CHECK (((period_end IS NULL) OR (period_start IS NULL) OR (period_end >= period_start))),
    CONSTRAINT courses_credit_check CHECK ((credit > (0)::numeric)),
    CONSTRAINT courses_period_end_check CHECK (((period_end >= 1) AND (period_end <= 12))),
    CONSTRAINT courses_period_start_check CHECK (((period_start >= 1) AND (period_start <= 12))),
    CONSTRAINT courses_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'open'::text, 'closed'::text, 'archived'::text]))),
    CONSTRAINT courses_weekday_check CHECK (((weekday >= 1) AND (weekday <= 7)))
);


--
-- Name: evaluation_submissions; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.evaluation_submissions (
    submission_id text NOT NULL,
    task_id text NOT NULL,
    student_id text NOT NULL,
    answers_json jsonb NOT NULL,
    average_score numeric(4,2),
    submitted_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: evaluation_tasks; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.evaluation_tasks (
    task_id text NOT NULL,
    template_id text,
    student_id text,
    course_id text,
    term text NOT NULL,
    teacher_name text,
    status text DEFAULT 'open'::text NOT NULL,
    open_time timestamp with time zone,
    close_time timestamp with time zone,
    submitted_at timestamp with time zone,
    CONSTRAINT evaluation_tasks_status_check CHECK ((status = ANY (ARRAY['open'::text, 'submitted'::text, 'closed'::text])))
);


--
-- Name: evaluation_templates; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.evaluation_templates (
    template_id text NOT NULL,
    name text NOT NULL,
    description text,
    question_count integer NOT NULL,
    status text DEFAULT 'enabled'::text NOT NULL,
    questions_json jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT evaluation_templates_question_count_check CHECK (((question_count >= 1) AND (question_count <= 50))),
    CONSTRAINT evaluation_templates_status_check CHECK ((status = ANY (ARRAY['enabled'::text, 'disabled'::text])))
);


--
-- Name: feedback_items; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.feedback_items (
    feedback_id text NOT NULL,
    student_id text,
    category text NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    contact text,
    state text DEFAULT 'submitted'::text NOT NULL,
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT feedback_items_category_check CHECK ((category = ANY (ARRAY['bug'::text, 'suggestion'::text, 'service'::text, 'other'::text]))),
    CONSTRAINT feedback_items_state_check CHECK ((state = ANY (ARRAY['submitted'::text, 'processing'::text, 'closed'::text])))
);


--
-- Name: grade_tasks; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.grade_tasks (
    task_id text NOT NULL,
    course_id text NOT NULL,
    term text NOT NULL,
    teaching_class_name text NOT NULL,
    teacher_name text NOT NULL,
    input_progress integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'inputting'::text NOT NULL,
    reject_reason text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT grade_tasks_input_progress_check CHECK (((input_progress >= 0) AND (input_progress <= 100))),
    CONSTRAINT grade_tasks_status_check CHECK ((status = ANY (ARRAY['inputting'::text, 'pendingAudit'::text, 'published'::text, 'appealed'::text, 'rejected'::text])))
);


--
-- Name: grades; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.grades (
    grade_id text NOT NULL,
    task_id text,
    student_id text NOT NULL,
    course_id text NOT NULL,
    term text NOT NULL,
    score numeric(5,2) NOT NULL,
    grade_point numeric(3,2),
    rank integer,
    published_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT grades_score_check CHECK (((score >= (0)::numeric) AND (score <= (100)::numeric)))
);


--
-- Name: leave_requests; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.leave_requests (
    leave_id text NOT NULL,
    student_id text NOT NULL,
    type text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    reason text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    feedback text,
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT leave_requests_check CHECK ((end_date >= start_date)),
    CONSTRAINT leave_requests_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'withdrawn'::text]))),
    CONSTRAINT leave_requests_type_check CHECK ((type = ANY (ARRAY['sick'::text, 'personal'::text, 'public'::text, 'other'::text])))
);


--
-- Name: message_templates; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.message_templates (
    template_id text NOT NULL,
    name text NOT NULL,
    channel text NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notice_reads; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.notice_reads (
    notice_id text NOT NULL,
    student_id text NOT NULL,
    read_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notices; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.notices (
    notice_id text NOT NULL,
    title text NOT NULL,
    publisher text NOT NULL,
    category text NOT NULL,
    urgency text DEFAULT 'normal'::text NOT NULL,
    summary text,
    content text NOT NULL,
    receiver_type text DEFAULT 'all'::text NOT NULL,
    receiver_scope_json jsonb DEFAULT '[]'::jsonb NOT NULL,
    publish_time timestamp with time zone,
    expire_time timestamp with time zone,
    published_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notices_receiver_type_check CHECK ((receiver_type = ANY (ARRAY['all'::text, 'students'::text, 'teachers'::text, 'custom'::text]))),
    CONSTRAINT notices_urgency_check CHECK ((urgency = ANY (ARRAY['normal'::text, 'important'::text, 'urgent'::text])))
);


--
-- Name: permissions; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.permissions (
    code text NOT NULL,
    action text NOT NULL,
    module text NOT NULL,
    name text NOT NULL
);


--
-- Name: practice_projects; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.practice_projects (
    project_id text NOT NULL,
    title text NOT NULL,
    org text NOT NULL,
    category text NOT NULL,
    credits numeric(4,1) NOT NULL,
    period text NOT NULL,
    location text,
    mentor text,
    slots_total integer NOT NULL,
    description text,
    requirements_json jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT practice_projects_category_check CHECK ((category = ANY (ARRAY['internship'::text, 'research'::text, 'social'::text, 'volunteer'::text]))),
    CONSTRAINT practice_projects_credits_check CHECK ((credits >= (0)::numeric)),
    CONSTRAINT practice_projects_slots_total_check CHECK ((slots_total >= 0))
);


--
-- Name: practice_signups; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.practice_signups (
    project_id text NOT NULL,
    student_id text NOT NULL,
    status text DEFAULT 'signedUp'::text NOT NULL,
    signed_at timestamp with time zone DEFAULT now() NOT NULL,
    cancelled_at timestamp with time zone,
    CONSTRAINT practice_signups_status_check CHECK ((status = ANY (ARRAY['signedUp'::text, 'cancelled'::text])))
);


--
-- Name: role_permissions; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.role_permissions (
    role_id text NOT NULL,
    code text NOT NULL,
    action text NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.roles (
    role_id text NOT NULL,
    name text NOT NULL,
    description text,
    member_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT roles_member_count_check CHECK ((member_count >= 0))
);


--
-- Name: schedule_items; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.schedule_items (
    schedule_id text NOT NULL,
    student_id text NOT NULL,
    term text NOT NULL,
    course_id text NOT NULL,
    type text DEFAULT 'normal'::text NOT NULL,
    weekday integer NOT NULL,
    period_start integer NOT NULL,
    period_end integer NOT NULL,
    start_time text,
    end_time text,
    classroom text,
    campus text,
    weeks_json jsonb DEFAULT '[]'::jsonb NOT NULL,
    week_text text,
    course_type text,
    imported boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT schedule_items_check CHECK ((period_end >= period_start)),
    CONSTRAINT schedule_items_period_end_check CHECK (((period_end >= 1) AND (period_end <= 12))),
    CONSTRAINT schedule_items_period_start_check CHECK (((period_start >= 1) AND (period_start <= 12))),
    CONSTRAINT schedule_items_type_check CHECK ((type = ANY (ARRAY['normal'::text, 'practice'::text]))),
    CONSTRAINT schedule_items_weekday_check CHECK (((weekday >= 1) AND (weekday <= 7)))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.schema_migrations (
    version integer NOT NULL,
    name text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: security_policy; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.security_policy (
    key text NOT NULL,
    value boolean NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: selection_rounds; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.selection_rounds (
    round_id text NOT NULL,
    name text NOT NULL,
    status text DEFAULT 'notStarted'::text NOT NULL,
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone NOT NULL,
    credit_limit numeric(4,1) DEFAULT 30 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT selection_rounds_check CHECK ((end_time > start_time)),
    CONSTRAINT selection_rounds_credit_limit_check CHECK ((credit_limit > (0)::numeric)),
    CONSTRAINT selection_rounds_status_check CHECK ((status = ANY (ARRAY['notStarted'::text, 'running'::text, 'paused'::text, 'ended'::text])))
);


--
-- Name: selections; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.selections (
    selection_id text NOT NULL,
    student_id text NOT NULL,
    course_id text NOT NULL,
    round_id text NOT NULL,
    status text DEFAULT 'selected'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    dropped_at timestamp with time zone,
    CONSTRAINT selections_status_check CHECK ((status = ANY (ARRAY['selected'::text, 'dropped'::text])))
);


--
-- Name: student_profiles; Type: TABLE; Schema: dtest2; Owner: -
--

CREATE TABLE dtest2.student_profiles (
    student_id text NOT NULL,
    name text NOT NULL,
    avatar_url text,
    college text NOT NULL,
    major text NOT NULL,
    class_name text NOT NULL,
    grade text NOT NULL,
    phone text,
    email text,
    address text,
    emergency_contact text,
    bio text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (account_id);


--
-- Name: admin_profiles admin_profiles_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.admin_profiles
    ADD CONSTRAINT admin_profiles_pkey PRIMARY KEY (admin_id);


--
-- Name: app_settings app_settings_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.app_settings
    ADD CONSTRAINT app_settings_pkey PRIMARY KEY (account_id, key);


--
-- Name: approval_flow_nodes approval_flow_nodes_node_order_key; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.approval_flow_nodes
    ADD CONSTRAINT approval_flow_nodes_node_order_key UNIQUE (node_order);


--
-- Name: approval_flow_nodes approval_flow_nodes_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.approval_flow_nodes
    ADD CONSTRAINT approval_flow_nodes_pkey PRIMARY KEY (node_id);


--
-- Name: approval_instances approval_instances_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.approval_instances
    ADD CONSTRAINT approval_instances_pkey PRIMARY KEY (approval_id);


--
-- Name: approval_steps approval_steps_approval_id_step_order_key; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.approval_steps
    ADD CONSTRAINT approval_steps_approval_id_step_order_key UNIQUE (approval_id, step_order);


--
-- Name: approval_steps approval_steps_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.approval_steps
    ADD CONSTRAINT approval_steps_pkey PRIMARY KEY (step_id);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (attachment_id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (log_id);


--
-- Name: calendar_events calendar_events_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.calendar_events
    ADD CONSTRAINT calendar_events_pkey PRIMARY KEY (event_id);


--
-- Name: courses courses_code_key; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.courses
    ADD CONSTRAINT courses_code_key UNIQUE (code);


--
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (course_id);


--
-- Name: evaluation_submissions evaluation_submissions_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.evaluation_submissions
    ADD CONSTRAINT evaluation_submissions_pkey PRIMARY KEY (submission_id);


--
-- Name: evaluation_submissions evaluation_submissions_task_id_student_id_key; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.evaluation_submissions
    ADD CONSTRAINT evaluation_submissions_task_id_student_id_key UNIQUE (task_id, student_id);


--
-- Name: evaluation_tasks evaluation_tasks_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.evaluation_tasks
    ADD CONSTRAINT evaluation_tasks_pkey PRIMARY KEY (task_id);


--
-- Name: evaluation_templates evaluation_templates_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.evaluation_templates
    ADD CONSTRAINT evaluation_templates_pkey PRIMARY KEY (template_id);


--
-- Name: feedback_items feedback_items_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.feedback_items
    ADD CONSTRAINT feedback_items_pkey PRIMARY KEY (feedback_id);


--
-- Name: grade_tasks grade_tasks_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.grade_tasks
    ADD CONSTRAINT grade_tasks_pkey PRIMARY KEY (task_id);


--
-- Name: grades grades_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.grades
    ADD CONSTRAINT grades_pkey PRIMARY KEY (grade_id);


--
-- Name: grades grades_student_id_course_id_term_key; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.grades
    ADD CONSTRAINT grades_student_id_course_id_term_key UNIQUE (student_id, course_id, term);


--
-- Name: leave_requests leave_requests_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.leave_requests
    ADD CONSTRAINT leave_requests_pkey PRIMARY KEY (leave_id);


--
-- Name: message_templates message_templates_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.message_templates
    ADD CONSTRAINT message_templates_pkey PRIMARY KEY (template_id);


--
-- Name: notice_reads notice_reads_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.notice_reads
    ADD CONSTRAINT notice_reads_pkey PRIMARY KEY (notice_id, student_id);


--
-- Name: notices notices_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.notices
    ADD CONSTRAINT notices_pkey PRIMARY KEY (notice_id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (code, action);


--
-- Name: practice_projects practice_projects_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.practice_projects
    ADD CONSTRAINT practice_projects_pkey PRIMARY KEY (project_id);


--
-- Name: practice_signups practice_signups_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.practice_signups
    ADD CONSTRAINT practice_signups_pkey PRIMARY KEY (project_id, student_id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, code, action);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role_id);


--
-- Name: schedule_items schedule_items_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.schedule_items
    ADD CONSTRAINT schedule_items_pkey PRIMARY KEY (schedule_id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: security_policy security_policy_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.security_policy
    ADD CONSTRAINT security_policy_pkey PRIMARY KEY (key);


--
-- Name: selection_rounds selection_rounds_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.selection_rounds
    ADD CONSTRAINT selection_rounds_pkey PRIMARY KEY (round_id);


--
-- Name: selections selections_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.selections
    ADD CONSTRAINT selections_pkey PRIMARY KEY (selection_id);


--
-- Name: selections selections_student_id_course_id_round_id_key; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.selections
    ADD CONSTRAINT selections_student_id_course_id_round_id_key UNIQUE (student_id, course_id, round_id);


--
-- Name: student_profiles student_profiles_pkey; Type: CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.student_profiles
    ADD CONSTRAINT student_profiles_pkey PRIMARY KEY (student_id);


--
-- Name: idx_approval_status; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_approval_status ON dtest2.approval_instances USING btree (status, submitted_at DESC);


--
-- Name: idx_attachments_owner; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_attachments_owner ON dtest2.attachments USING btree (owner_type, owner_id);


--
-- Name: idx_audit_operator_time; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_audit_operator_time ON dtest2.audit_logs USING btree (operator_id, created_at DESC);


--
-- Name: idx_audit_type_time; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_audit_type_time ON dtest2.audit_logs USING btree (action_type, created_at DESC);


--
-- Name: idx_calendar_date; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_calendar_date ON dtest2.calendar_events USING btree (event_date);


--
-- Name: idx_courses_category; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_courses_category ON dtest2.courses USING btree (category);


--
-- Name: idx_courses_status; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_courses_status ON dtest2.courses USING btree (status);


--
-- Name: idx_evaluation_tasks_student; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_evaluation_tasks_student ON dtest2.evaluation_tasks USING btree (student_id, term, status);


--
-- Name: idx_grade_tasks_status; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_grade_tasks_status ON dtest2.grade_tasks USING btree (status);


--
-- Name: idx_grades_student_term; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_grades_student_term ON dtest2.grades USING btree (student_id, term);


--
-- Name: idx_leave_student_status; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_leave_student_status ON dtest2.leave_requests USING btree (student_id, status);


--
-- Name: idx_notices_category_time; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_notices_category_time ON dtest2.notices USING btree (category, published_at DESC);


--
-- Name: idx_schedule_student_term; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_schedule_student_term ON dtest2.schedule_items USING btree (student_id, term);


--
-- Name: idx_schedule_time; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_schedule_time ON dtest2.schedule_items USING btree (student_id, term, weekday, period_start, period_end);


--
-- Name: idx_selections_course; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_selections_course ON dtest2.selections USING btree (course_id, status);


--
-- Name: idx_selections_student; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE INDEX idx_selections_student ON dtest2.selections USING btree (student_id, status);


--
-- Name: uq_approval_biz; Type: INDEX; Schema: dtest2; Owner: -
--

CREATE UNIQUE INDEX uq_approval_biz ON dtest2.approval_instances USING btree (biz_type, biz_id);


--
-- Name: admin_profiles admin_profiles_admin_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.admin_profiles
    ADD CONSTRAINT admin_profiles_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES dtest2.accounts(account_id) ON DELETE CASCADE;


--
-- Name: admin_profiles admin_profiles_role_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.admin_profiles
    ADD CONSTRAINT admin_profiles_role_id_fkey FOREIGN KEY (role_id) REFERENCES dtest2.roles(role_id);


--
-- Name: approval_steps approval_steps_approval_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.approval_steps
    ADD CONSTRAINT approval_steps_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES dtest2.approval_instances(approval_id) ON DELETE CASCADE;


--
-- Name: approval_steps approval_steps_operator_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.approval_steps
    ADD CONSTRAINT approval_steps_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES dtest2.admin_profiles(admin_id);


--
-- Name: evaluation_submissions evaluation_submissions_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.evaluation_submissions
    ADD CONSTRAINT evaluation_submissions_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.student_profiles(student_id) ON DELETE CASCADE;


--
-- Name: evaluation_submissions evaluation_submissions_task_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.evaluation_submissions
    ADD CONSTRAINT evaluation_submissions_task_id_fkey FOREIGN KEY (task_id) REFERENCES dtest2.evaluation_tasks(task_id) ON DELETE CASCADE;


--
-- Name: evaluation_tasks evaluation_tasks_course_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.evaluation_tasks
    ADD CONSTRAINT evaluation_tasks_course_id_fkey FOREIGN KEY (course_id) REFERENCES dtest2.courses(course_id) ON DELETE CASCADE;


--
-- Name: evaluation_tasks evaluation_tasks_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.evaluation_tasks
    ADD CONSTRAINT evaluation_tasks_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.student_profiles(student_id) ON DELETE CASCADE;


--
-- Name: evaluation_tasks evaluation_tasks_template_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.evaluation_tasks
    ADD CONSTRAINT evaluation_tasks_template_id_fkey FOREIGN KEY (template_id) REFERENCES dtest2.evaluation_templates(template_id);


--
-- Name: feedback_items feedback_items_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.feedback_items
    ADD CONSTRAINT feedback_items_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.student_profiles(student_id) ON DELETE SET NULL;


--
-- Name: grade_tasks grade_tasks_course_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.grade_tasks
    ADD CONSTRAINT grade_tasks_course_id_fkey FOREIGN KEY (course_id) REFERENCES dtest2.courses(course_id) ON DELETE CASCADE;


--
-- Name: grades grades_course_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.grades
    ADD CONSTRAINT grades_course_id_fkey FOREIGN KEY (course_id) REFERENCES dtest2.courses(course_id) ON DELETE CASCADE;


--
-- Name: grades grades_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.grades
    ADD CONSTRAINT grades_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.student_profiles(student_id) ON DELETE CASCADE;


--
-- Name: grades grades_task_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.grades
    ADD CONSTRAINT grades_task_id_fkey FOREIGN KEY (task_id) REFERENCES dtest2.grade_tasks(task_id) ON DELETE SET NULL;


--
-- Name: leave_requests leave_requests_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.leave_requests
    ADD CONSTRAINT leave_requests_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.student_profiles(student_id) ON DELETE CASCADE;


--
-- Name: notice_reads notice_reads_notice_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.notice_reads
    ADD CONSTRAINT notice_reads_notice_id_fkey FOREIGN KEY (notice_id) REFERENCES dtest2.notices(notice_id) ON DELETE CASCADE;


--
-- Name: notice_reads notice_reads_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.notice_reads
    ADD CONSTRAINT notice_reads_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.student_profiles(student_id) ON DELETE CASCADE;


--
-- Name: notices notices_created_by_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.notices
    ADD CONSTRAINT notices_created_by_fkey FOREIGN KEY (created_by) REFERENCES dtest2.admin_profiles(admin_id);


--
-- Name: practice_signups practice_signups_project_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.practice_signups
    ADD CONSTRAINT practice_signups_project_id_fkey FOREIGN KEY (project_id) REFERENCES dtest2.practice_projects(project_id) ON DELETE CASCADE;


--
-- Name: practice_signups practice_signups_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.practice_signups
    ADD CONSTRAINT practice_signups_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.student_profiles(student_id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_code_action_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.role_permissions
    ADD CONSTRAINT role_permissions_code_action_fkey FOREIGN KEY (code, action) REFERENCES dtest2.permissions(code, action) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES dtest2.roles(role_id) ON DELETE CASCADE;


--
-- Name: schedule_items schedule_items_course_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.schedule_items
    ADD CONSTRAINT schedule_items_course_id_fkey FOREIGN KEY (course_id) REFERENCES dtest2.courses(course_id) ON DELETE CASCADE;


--
-- Name: schedule_items schedule_items_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.schedule_items
    ADD CONSTRAINT schedule_items_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.student_profiles(student_id) ON DELETE CASCADE;


--
-- Name: selections selections_course_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.selections
    ADD CONSTRAINT selections_course_id_fkey FOREIGN KEY (course_id) REFERENCES dtest2.courses(course_id) ON DELETE CASCADE;


--
-- Name: selections selections_round_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.selections
    ADD CONSTRAINT selections_round_id_fkey FOREIGN KEY (round_id) REFERENCES dtest2.selection_rounds(round_id) ON DELETE RESTRICT;


--
-- Name: selections selections_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.selections
    ADD CONSTRAINT selections_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.student_profiles(student_id) ON DELETE CASCADE;


--
-- Name: student_profiles student_profiles_student_id_fkey; Type: FK CONSTRAINT; Schema: dtest2; Owner: -
--

ALTER TABLE ONLY dtest2.student_profiles
    ADD CONSTRAINT student_profiles_student_id_fkey FOREIGN KEY (student_id) REFERENCES dtest2.accounts(account_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--



-- 记录本迁移已应用（与既有 schema_migrations 约定一致；幂等，可重复执行）
INSERT INTO dtest2.schema_migrations (version, name)
SELECT 1, 'initial_dtest2_schema'
WHERE NOT EXISTS (SELECT 1 FROM dtest2.schema_migrations WHERE version = 1);
