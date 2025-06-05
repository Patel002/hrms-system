import OdPass from '../model/odPass.model.js';
import { Company } from '../utils/join.js';
import { Op } from 'sequelize';

const createOdPass = async(req, res) =>{
    const {
        emp_id,
        comp_fname,    
        fromdate,
        todate,
        add_date,
        oddays,
        odtype,
        remark,
        created_by,
        created_at
    } = req.body

    try {

        if(!emp_id || !comp_fname || !fromdate || !todate || !add_date || !oddays || !odtype || !remark ){
            return res.status(400).json({message:"All fields are required"})
        }

        const company = await Company.findOne({ where: { comp_fname } });
        if (!company) {
            return res.status(404).json({ message: "Company not found" });
        }

        console.log("comp_ID",company.comp_id);

        if(fromdate > todate){
            return res.status(400).json({message:"From date should be less than to date"})
        }

        const existingOd = await OdPass.findOne({
            where: {
                emp_id,
                [Op.or]: [
                    {
                        fromdate: {
                            [Op.between]: [fromdate, todate]
                        }
                    },
                    {
                        todate: {
                            [Op.between]: [fromdate, todate]
                        }
                    },
                    {
                    [Op.and]: [
                        {
                            fromdate: {
                                [Op.lte]: fromdate
                            }
                        },
                        {
                            todate: {
                                [Op.gte]: todate
                            }
                        }
                    ]
                }
              ]
            }
        })

        if (existingOd) {
            return res.status(409).json({ message: "OD Pass already requested for overlapping dates" });
        }

        const odPass = await OdPass.create({
            emp_id,
            comp_id: company.comp_id,
            add_date,
            fromdate,
            todate,
            oddays,
            odtype,
            remark,
            status: '1',
            app_type: 'OD',
            created_by,
            approved: 'PENDING',
            approve_step1: '0',
            created_at,

        })

        console.log("odPass",odPass);

        res.status(201).json({message:"OD Pass created successfully", odPass})
        
    } catch (error) {
        console.log("Getting error from od pass",error);
        res.status(500).json({message:"server side error"})
    }
}

const getHistoryOfOdPass = async(req, res) =>{
    const {emp_id, approved} = req.query;
    try {

        const odPass = await OdPass.findAll({ where: { emp_id, approved } });
        if (!odPass) {
            return res.status(404).json({ message: "Employee not found" });
        }
        res.status(200).json({message:"History of od pass fetched successfully", odPass})
        
    } catch (error) {
        console.log("error from get history of od pass",error);
        return res.status(500).json({message:"server side error"})
    }
}

export {
    createOdPass,
    getHistoryOfOdPass
}