import test from 'node:test';
import assert from 'node:assert/strict';
import {groupCounts,escapeHtml} from './stats.js';
test('문항 수정 이력별 집계와 A/B 합산',()=>{const rows=[{question_id:'1',title:'old',option_a:'a',option_b:'b',choice:'A',total:2},{question_id:'1',title:'old',option_a:'a',option_b:'b',choice:'B',total:3},{question_id:'1',title:'new',option_a:'c',option_b:'d',choice:'B',total:1}];const g=groupCounts(rows);assert.equal(g.length,2);assert.equal(g[0].A,2);assert.equal(g[0].B,3);assert.equal(g[1].B,1);assert.deepEqual(groupCounts([]),[]);});
test('자유 응답 HTML 실행 방지',()=>assert.equal(escapeHtml('<script>"&'), '&lt;script&gt;&quot;&amp;'));
