export function groupCounts(rows){
 const groups=new Map();
 for(const row of rows){const key=JSON.stringify([row.question_id,row.title,row.option_a,row.option_b]);if(!groups.has(key))groups.set(key,{...row,A:0,B:0});groups.get(key)[row.choice]+=Number(row.total);}
 return [...groups.values()];
}
export const escapeHtml=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
