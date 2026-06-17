import { Model } from 'pinia-orm';
import { Attr, Str, Uid, Num, Bool } from 'pinia-orm/decorators';
import { useAxiosRepo } from '@pinia-orm/axios';

//#region Human-Code Preservation

//#endregion Human-Code Preservation

// 使用 VITE_BACKEND_URL（install.html 配置的后端服务域名）
const apiURL = import.meta.env.VITE_BACKEND_URL || 'https://localhost:443';

export class {{table_name}} extends Model {
  static override entity = '{{table_name}}'

{{fields}}

  static override config = {
    axiosApi: {
      actions: {
        get{{ClassName}}List(page: number, pageSize: number, searchParams?: any) {
          return useAxiosRepo({{table_name}}).api().get(`/api/v1/{{db_name}}/{{table_name}}/${pageSize}/${page}`, {
            params: searchParams,
            headers: {
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
            },
            baseURL: apiURL,
            dataKey: '{{table_name}}s'
          })
        },

        get{{ClassName}}(id: string) {
          return useAxiosRepo({{table_name}}).api().get(`/api/v1/{{db_name}}/{{table_name}}/${id}`, {
            headers: {
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
            },
            baseURL: apiURL,
          })
        },

        add{{ClassName}}(data: any) {
          return useAxiosRepo({{table_name}}).api().post('/api/v1/{{db_name}}/{{table_name}}/add', data, {
            headers: {
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
            },
            baseURL: apiURL,
          })
        },

        edit{{ClassName}}(data: any) {
          return useAxiosRepo({{table_name}}).api().post('/api/v1/{{db_name}}/{{table_name}}/edit', data, {
            headers: {
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
            },
            baseURL: apiURL,
          })
        },

        delete{{ClassName}}(data: any) {
          return useAxiosRepo({{table_name}}).api().post('/api/v1/{{db_name}}/{{table_name}}/del', data, {
            headers: {
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
            },
            baseURL: apiURL,
          })
        },

        batchDelete{{ClassName}}(params: { ids: string; force?: number }) {
          return useAxiosRepo({{table_name}}).api().post('/api/v1/{{db_name}}/{{table_name}}/del', params, {
            headers: {
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
            },
            baseURL: apiURL,
          })
        },

        batchRestore{{ClassName}}(ids: string[]) {
          return useAxiosRepo({{table_name}}).api().post('/api/v1/{{db_name}}/{{table_name}}/edit', { ids: JSON.stringify(ids), deleted_at: '0' }, {
            headers: {
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
            },
            baseURL: apiURL,
          })
        },

        emptyRecycleBin() {
          return useAxiosRepo({{table_name}}).api().post('/api/v1/{{db_name}}/{{table_name}}/empty-recycle-bin', {}, {
            headers: {
              'Content-Type': 'application/json;charset=utf-8',
              'Authorization': `Bearer ${localStorage.getItem('accessToken')}`
            },
            baseURL: apiURL,
          })
        },

//#region Human-Code Preservation

//#endregion Human-Code Preservation
      }
    }
  }
}
