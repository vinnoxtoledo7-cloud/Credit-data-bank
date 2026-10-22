-- Preserve API signatures while removing privileged code from the exposed schema.
-- Only the six reviewed legacy RPCs are affected. Ownership checks remain inside each implementation.
do $migration$
declare f record; definition text; call_args text; signature text;
begin
 for f in
 select p.oid,p.proname,p.proargnames,pg_get_function_identity_arguments(p.oid) args,pg_get_function_result(p.oid) result
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname in ('credit_demo_entry','credit_demo_transfer','payroll_approve','payroll_assign_approver','payroll_simulate_payment','payroll_submit')
 loop
  definition:=pg_get_functiondef(f.oid);
  if definition not like '%SECURITY DEFINER%' then raise exception 'Unexpected legacy RPC state: %',f.proname;end if;
  definition:=replace(definition,'FUNCTION public.'||f.proname||'(','FUNCTION credit_private.'||f.proname||'(');
  definition:=regexp_replace(definition,'\mbegin\M', 'begin if auth.uid() is null then raise exception ''Autenticação obrigatória''; end if;', 'i');
  if f.proname='credit_demo_entry' then
   definition:=replace(definition,'if p_kind not in','if p_kind is null or p_kind not in');
  end if;
  if f.proname='payroll_assign_approver' then
   definition:=replace(definition,'if p_role not in','if p_role is null or p_role not in');
  end if;
  if f.proname in ('credit_demo_entry','credit_demo_transfer') then
   definition:=replace(definition,'p_amount is null or','p_amount is null or p_amount::text in (''NaN'',''Infinity'',''-Infinity'') or');
  end if;
  execute definition;
  select string_agg(quote_ident(a),',') into call_args from unnest(f.proargnames) a;
  execute format('create or replace function public.%I(%s) returns %s language sql security invoker set search_path='''' as %L',f.proname,f.args,f.result,format('select credit_private.%I(%s)',f.proname,call_args));
  signature:=format('%I(%s)',f.proname,f.args);
  execute 'revoke all on function public.'||signature||' from public,anon';
  execute 'revoke all on function credit_private.'||signature||' from public,anon';
  execute 'grant execute on function public.'||signature||' to authenticated';
  execute 'grant execute on function credit_private.'||signature||' to authenticated';
 end loop;
end $migration$;
